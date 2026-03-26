package com.budgetbook.common.exception

import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import jakarta.validation.ConstraintViolation
import jakarta.validation.ConstraintViolationException
import jakarta.validation.Path
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.http.HttpStatus
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.validation.BeanPropertyBindingResult
import org.springframework.validation.FieldError
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.core.MethodParameter

class GlobalExceptionHandlerTest : FunSpec({

    val handler = GlobalExceptionHandler()

    test("handleBusinessException returns correct status and error for NotFoundException") {
        val exception = NotFoundException("USER_NOT_FOUND", "User not found")

        val response = handler.handleBusinessException(exception)

        response.statusCode shouldBe HttpStatus.NOT_FOUND
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "USER_NOT_FOUND"
        response.body!!.error!!.message shouldBe "User not found"
        response.body!!.data shouldBe null
    }

    test("handleBusinessException returns correct status for UnauthorizedException") {
        val exception = UnauthorizedException("INVALID_TOKEN", "Token is invalid")

        val response = handler.handleBusinessException(exception)

        response.statusCode shouldBe HttpStatus.UNAUTHORIZED
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "INVALID_TOKEN"
        response.body!!.error!!.message shouldBe "Token is invalid"
    }

    test("handleBusinessException returns correct status for ForbiddenException") {
        val exception = ForbiddenException("FORBIDDEN", "Access denied")

        val response = handler.handleBusinessException(exception)

        response.statusCode shouldBe HttpStatus.FORBIDDEN
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "FORBIDDEN"
    }

    test("handleBusinessException returns correct status for ConflictException") {
        val exception = ConflictException("DUPLICATE_RESOURCE", "Email already exists")

        val response = handler.handleBusinessException(exception)

        response.statusCode shouldBe HttpStatus.CONFLICT
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "DUPLICATE_RESOURCE"
    }

    test("handleBusinessException returns BAD_REQUEST for base BusinessException") {
        val exception = BusinessException("BAD_REQUEST", "Invalid request")

        val response = handler.handleBusinessException(exception)

        response.statusCode shouldBe HttpStatus.BAD_REQUEST
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "BAD_REQUEST"
    }

    test("handleValidationException returns BAD_REQUEST with field error messages") {
        val bindingResult = BeanPropertyBindingResult(Any(), "testObject")
        bindingResult.addError(FieldError("testObject", "email", "must not be blank"))
        bindingResult.addError(FieldError("testObject", "name", "must not be empty"))

        // Use the (MethodParameter, BindingResult) constructor with a real MethodParameter
        val methodParameter = MethodParameter(
            GlobalExceptionHandler::class.java.getDeclaredMethod("handleValidationException", MethodArgumentNotValidException::class.java),
            0
        )
        val exception = MethodArgumentNotValidException(methodParameter, bindingResult)

        val response = handler.handleValidationException(exception)

        response.statusCode shouldBe HttpStatus.BAD_REQUEST
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "VALIDATION_ERROR"
        response.body!!.error!!.message shouldContain "email: must not be blank"
        response.body!!.error!!.message shouldContain "name: must not be empty"
    }

    test("handleDataIntegrityViolation returns BAD_REQUEST with CONSTRAINT_VIOLATION") {
        val exception = DataIntegrityViolationException("duplicate key value")

        val response = handler.handleDataIntegrityViolation(exception)

        response.statusCode shouldBe HttpStatus.BAD_REQUEST
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "CONSTRAINT_VIOLATION"
        response.body!!.error!!.message shouldBe "Data integrity constraint violated"
    }

    test("handleConstraintViolation returns BAD_REQUEST with VALIDATION_ERROR") {
        val path = io.mockk.mockk<Path>()
        io.mockk.every { path.toString() } returns "year"
        val violation = io.mockk.mockk<ConstraintViolation<*>>()
        io.mockk.every { violation.propertyPath } returns path
        io.mockk.every { violation.message } returns "must be at least 2000"
        val exception = ConstraintViolationException(setOf(violation))

        val response = handler.handleConstraintViolation(exception)

        response.statusCode shouldBe HttpStatus.BAD_REQUEST
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "VALIDATION_ERROR"
        response.body!!.error!!.message shouldContain "year: must be at least 2000"
    }

    test("handleHttpMessageNotReadable returns BAD_REQUEST") {
        val exception = HttpMessageNotReadableException("Could not read JSON")

        val response = handler.handleHttpMessageNotReadable(exception)

        response.statusCode shouldBe HttpStatus.BAD_REQUEST
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "BAD_REQUEST"
        response.body!!.error!!.message shouldBe "Malformed request body"
    }

    test("handleException returns INTERNAL_SERVER_ERROR for unexpected exceptions") {
        val exception = RuntimeException("Something went wrong")

        val response = handler.handleException(exception)

        response.statusCode shouldBe HttpStatus.INTERNAL_SERVER_ERROR
        response.body!!.success shouldBe false
        response.body!!.error!!.code shouldBe "INTERNAL_ERROR"
        response.body!!.error!!.message shouldBe "An unexpected error occurred"
    }
})
