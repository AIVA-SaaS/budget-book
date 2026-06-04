package com.budgetbook.admin.integration

import org.testcontainers.dockerclient.DockerClientProviderStrategy
import org.testcontainers.dockerclient.InvalidConfigurationException
import org.testcontainers.dockerclient.TransportConfig
import java.io.IOException
import java.net.URI
import java.net.UnixDomainSocketAddress
import java.nio.channels.SocketChannel

/**
 * Custom Testcontainers Docker strategy for Docker Desktop on macOS.
 *
 * Docker Desktop 4.x proxy rejects API version-prefixed requests like /v1.32/info
 * with empty 400 responses. docker-java defaults to v1.32, causing all built-in
 * Testcontainers strategies to fail.
 *
 * This strategy:
 * 1. Verifies the Docker socket exists.
 * 2. Sends a raw /_ping HTTP request (no version prefix) directly over the Unix socket.
 *    Docker Desktop accepts /[no version]/_ping and responds 200, confirming connectivity.
 * 3. Returns a TransportConfig that Testcontainers uses to build its Docker client.
 *    The client itself may still use v1.32 for subsequent calls, but those are
 *    executed with a valid, connected socket and Docker Desktop handles them.
 */
class HighApiVersionDockerStrategy : DockerClientProviderStrategy() {

    private val socketPath = "/var/run/docker.sock"

    override fun getTransportConfig(): TransportConfig {
        if (!java.io.File(socketPath).exists()) {
            throw InvalidConfigurationException("Docker socket not found at $socketPath")
        }
        return TransportConfig.builder()
            .dockerHost(URI.create("unix://$socketPath"))
            .build()
    }

    override fun isApplicable(): Boolean = java.io.File(socketPath).exists()

    override fun getDescription(): String = "HighApiVersionDockerStrategy (macOS Docker Desktop workaround)"

    override fun getPriority(): Int = 100

    /**
     * Overrides the default test() which calls docker-java's infoCmd (uses /v1.32/info).
     * Instead, sends a raw HTTP GET /_ping to the Unix socket.
     * Docker Desktop responds 200 to /ping without a version prefix.
     */
    override fun test(): Boolean {
        if (!java.io.File(socketPath).exists()) return false
        return try {
            val addr = UnixDomainSocketAddress.of(socketPath)
            SocketChannel.open(addr).use { channel ->
                val request = "GET /_ping HTTP/1.0\r\nHost: localhost\r\n\r\n"
                val buf = java.nio.ByteBuffer.wrap(request.toByteArray())
                channel.write(buf)
                val response = java.nio.ByteBuffer.allocate(256)
                channel.read(response)
                val responseStr = String(response.array(), 0, response.position())
                responseStr.contains("200 OK")
            }
        } catch (_: IOException) {
            false
        }
    }
}
