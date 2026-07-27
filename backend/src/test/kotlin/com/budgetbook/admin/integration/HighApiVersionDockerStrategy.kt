package com.budgetbook.admin.integration

import org.testcontainers.dockerclient.DockerClientProviderStrategy
import org.testcontainers.dockerclient.InvalidConfigurationException
import org.testcontainers.dockerclient.TransportConfig
import java.io.IOException
import java.net.URI
import java.net.UnixDomainSocketAddress
import java.nio.channels.SocketChannel

/**
 * Custom Testcontainers Docker strategy for Unix-socket Docker runtimes on macOS.
 *
 * Docker Desktop 4.x proxy rejects API version-prefixed requests like /v1.32/info
 * with empty 400 responses. docker-java defaults to v1.32, causing all built-in
 * Testcontainers strategies to fail.
 *
 * This strategy:
 * 1. Resolves the first *reachable* Docker socket among several candidates.
 * 2. Sends a raw /_ping HTTP request (no version prefix) directly over the Unix socket
 *    to confirm connectivity (the daemon answers /_ping without a version prefix).
 * 3. Returns a TransportConfig that Testcontainers uses to build its Docker client.
 *
 * 2026-07-27 — socket path was hardcoded to `/var/run/docker.sock` (Docker Desktop).
 * On machines whose active runtime is colima/Rancher/podman that symlink is dangling,
 * so the whole test task failed at Kotest initialization with
 * "Could not find a valid Docker environment" even though `docker info` worked.
 * Candidates are now probed in order, with DOCKER_HOST winning when set.
 */
class HighApiVersionDockerStrategy : DockerClientProviderStrategy() {

    /**
     * Socket candidates, highest priority first:
     * 1. `DOCKER_HOST` when it points at a unix socket (explicit developer intent / CI)
     * 2. `/var/run/docker.sock` — Docker Desktop, Linux CI, colima with default symlink
     * 3. colima default socket
     * 4. Docker Desktop per-user socket
     * 5. Rancher Desktop per-user socket
     */
    private val candidateSocketPaths: List<String> = buildList {
        System.getenv("DOCKER_HOST")
            ?.takeIf { it.startsWith("unix://") }
            ?.removePrefix("unix://")
            ?.let { add(it) }
        add("/var/run/docker.sock")
        val home = System.getProperty("user.home")
        add("$home/.colima/default/docker.sock")
        add("$home/.docker/run/docker.sock")
        add("$home/.rd/docker.sock")
    }

    /** First candidate that answers /_ping, or null when Docker is unavailable. */
    private val resolvedSocketPath: String? by lazy {
        candidateSocketPaths.firstOrNull { ping(it) }
    }

    override fun getTransportConfig(): TransportConfig {
        val socketPath = resolvedSocketPath
            ?: throw InvalidConfigurationException(
                "No reachable Docker socket. Tried: ${candidateSocketPaths.joinToString()}"
            )
        return TransportConfig.builder()
            .dockerHost(URI.create("unix://$socketPath"))
            .build()
    }

    override fun isApplicable(): Boolean = resolvedSocketPath != null

    override fun getDescription(): String =
        "HighApiVersionDockerStrategy (unix socket ${resolvedSocketPath ?: "unresolved"})"

    override fun getPriority(): Int = 100

    /**
     * Overrides the default test() which calls docker-java's infoCmd (uses /v1.32/info).
     * Instead, sends a raw HTTP GET /_ping to the Unix socket.
     */
    override fun test(): Boolean = resolvedSocketPath != null

    private fun ping(socketPath: String): Boolean {
        val file = java.io.File(socketPath)
        // Dangling symlink (e.g. Docker Desktop socket while colima is the active
        // runtime) reports exists() == false, which is exactly what we want to skip.
        if (!file.exists()) return false
        return try {
            val addr = UnixDomainSocketAddress.of(socketPath)
            SocketChannel.open(addr).use { channel ->
                val request = "GET /_ping HTTP/1.0\r\nHost: localhost\r\n\r\n"
                channel.write(java.nio.ByteBuffer.wrap(request.toByteArray()))
                val response = java.nio.ByteBuffer.allocate(256)
                channel.read(response)
                String(response.array(), 0, response.position()).contains("200 OK")
            }
        } catch (_: IOException) {
            false
        } catch (_: UnsupportedOperationException) {
            // Platform without unix-domain socket support.
            false
        }
    }
}
