package com.budgetbook.common.exception

import org.springframework.http.HttpStatus

open class BusinessException(
    val code: String,
    override val message: String,
    val status: HttpStatus = HttpStatus.BAD_REQUEST
) : RuntimeException(message)

class NotFoundException(code: String, message: String) :
    BusinessException(code, message, HttpStatus.NOT_FOUND)

class UnauthorizedException(code: String, message: String) :
    BusinessException(code, message, HttpStatus.UNAUTHORIZED)

class ForbiddenException(code: String, message: String) :
    BusinessException(code, message, HttpStatus.FORBIDDEN)

class ConflictException(code: String, message: String) :
    BusinessException(code, message, HttpStatus.CONFLICT)
