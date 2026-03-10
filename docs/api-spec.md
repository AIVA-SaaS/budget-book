# Budget Book API Specification

> **Single Source of Truth** for all API contracts.
> Both Backend and Frontend MUST conform to this document.
> Any API change MUST update this file FIRST, then implement.

---

## Table of Contents

- [Common Response Format](#common-response-format)
- [Authentication](#authentication)
  - [OAuth2 Login Redirect](#1-oauth2-login-redirect)
  - [Refresh Token](#2-refresh-token)
  - [Get Current User](#3-get-current-user)
  - [Logout](#4-logout)
- [Couple](#couple)
  - [Create Invitation Code](#1-create-invitation-code)
  - [Accept Invitation](#2-accept-invitation)
  - [Get My Couple](#3-get-my-couple)
  - [Dissolve Couple](#4-dissolve-couple)
- [Categories](#categories)
  - [List Categories](#1-list-categories)
  - [Create Category](#2-create-category)
  - [Update Category](#3-update-category)
  - [Delete Category](#4-delete-category)
- [Transactions](#transactions)
  - [List Transactions](#1-list-transactions)
  - [Create Transaction](#2-create-transaction)
  - [Get Transaction](#3-get-transaction)
  - [Update Transaction](#4-update-transaction)
  - [Delete Transaction](#5-delete-transaction)
- [Common Data Types](#common-data-types)
- [Error Codes](#error-codes)

---

## Common Response Format

All API responses are wrapped in `ApiResponse<T>`:

```json
{
  "success": true,
  "data": T,
  "error": null,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

**Success response** (`success: true`):

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Error response** (`success: false`):

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

### HTTP Status Code Conventions

| Status Code | Usage                                      |
|:-----------:|:-------------------------------------------|
| `200`       | Success                                    |
| `201`       | Resource created                           |
| `204`       | Success with no content                    |
| `302`       | Redirect (OAuth2 flow)                     |
| `400`       | Bad request / Validation error             |
| `401`       | Unauthorized / Token invalid or expired    |
| `403`       | Forbidden / Insufficient permissions       |
| `404`       | Resource not found                         |
| `409`       | Conflict / Duplicate resource              |
| `500`       | Internal server error                      |

---

## Authentication

Base path: `/api/v1/auth`

All authenticated endpoints require the `Authorization` header:

```
Authorization: Bearer {accessToken}
```

---

### 1. OAuth2 Login Redirect

Redirects the user to the OAuth provider's authorization page.

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/oauth2/authorization/{provider}`       |
| **Auth**    | Not required                             |

**Path Parameters**

| Parameter  | Type     | Required | Description                   |
|:-----------|:---------|:--------:|:------------------------------|
| `provider` | `string` | Yes      | OAuth provider: `google`, `kakao` |

**Request Body**: None

**Response**: `302 Redirect`

On successful OAuth authentication, the server redirects to:

```
{FRONTEND_URL}/auth/callback?accessToken={jwt}&refreshToken={refreshToken}
```

**Example**

```
GET /oauth2/authorization/google

HTTP/1.1 302 Found
Location: https://accounts.google.com/o/oauth2/v2/auth?client_id=...&redirect_uri=...&scope=...
```

After successful provider authentication and callback:

```
HTTP/1.1 302 Found
Location: https://budget-book.app/auth/callback?accessToken=eyJhbGci...&refreshToken=dGhpcyBpcyBh...
```

---

### 2. Refresh Token

Issues a new access token using a valid refresh token.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `POST`                       |
| **Path**    | `/api/v1/auth/refresh`       |
| **Auth**    | Not required                 |

**Request Body**

```json
{
  "refreshToken": "string"
}
```

| Field          | Type     | Required | Description              |
|:---------------|:---------|:--------:|:-------------------------|
| `refreshToken` | `string` | Yes      | Valid, non-expired refresh token |

**Response `200 OK`**: `ApiResponse<TokenResponse>`

```json
{
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "dGhpcyBpcyBhIHJlZnJlc2ggdG9rZW4...",
    "expiresIn": 3600
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INVALID_REFRESH_TOKEN",
    "message": "The refresh token is invalid or has been revoked."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 3. Get Current User

Retrieves the profile of the currently authenticated user.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `GET`                        |
| **Path**    | `/api/v1/auth/me`            |
| **Auth**    | Required                     |

**Headers**

| Header          | Value                    | Required |
|:----------------|:-------------------------|:--------:|
| `Authorization` | `Bearer {accessToken}`   | Yes      |

**Request Body**: None

**Response `200 OK`**: `ApiResponse<UserResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "nickname": "홍길동",
    "profileImageUrl": "https://lh3.googleusercontent.com/...",
    "provider": "GOOGLE",
    "role": "USER",
    "coupleId": "550e8400-e29b-41d4-a716-446655440001",
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

Note: `coupleId` is `null` when the user is not in an active couple. This allows the frontend to decide routing immediately after login.

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "The access token is invalid or has expired."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 4. Logout

Revokes the refresh token and invalidates the current session.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `POST`                       |
| **Path**    | `/api/v1/auth/logout`        |
| **Auth**    | Required                     |

**Headers**

| Header          | Value                    | Required |
|:----------------|:-------------------------|:--------:|
| `Authorization` | `Bearer {accessToken}`   | Yes      |

**Request Body**

```json
{
  "refreshToken": "string"
}
```

| Field          | Type     | Required | Description                     |
|:---------------|:---------|:--------:|:--------------------------------|
| `refreshToken` | `string` | Yes      | Refresh token to revoke         |

**Response `200 OK`**: `ApiResponse<null>`

```json
{
  "success": true,
  "data": null,
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "The access token is invalid or has expired."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

---

## Couple

Base path: `/api/v1/couples`

All endpoints require the `Authorization: Bearer {accessToken}` header.

---

### 1. Create Invitation Code

Generates a new 8-character invitation code. The previous pending invitation for this user is automatically cancelled.

| Item        | Value                                      |
|:------------|:-------------------------------------------|
| **Method**  | `POST`                                     |
| **Path**    | `/api/v1/couples/invitations`              |
| **Auth**    | Required                                   |

**Request Body**: None

**Response `201 Created`**: `ApiResponse<InvitationResponse>`

```json
{
  "success": true,
  "data": {
    "code": "A3F9K2BX",
    "expiresAt": "2024-01-02T12:00:00Z"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `409 Conflict`**: `ApiResponse<null>` — user is already in an active couple

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "COUPLE_ALREADY_EXISTS",
    "message": "User is already in an active couple."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 2. Accept Invitation

Accepts an invitation code and links the two users as a couple. Default categories are seeded automatically upon acceptance.

| Item        | Value                                          |
|:------------|:-----------------------------------------------|
| **Method**  | `POST`                                         |
| **Path**    | `/api/v1/couples/invitations/{code}/accept`    |
| **Auth**    | Required                                       |

**Path Parameters**

| Parameter | Type     | Required | Description          |
|:----------|:---------|:--------:|:---------------------|
| `code`    | `string` | Yes      | 8-character invite code |

**Request Body**: None

**Response `200 OK`**: `ApiResponse<CoupleResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "partner": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "홍길동",
      "profileImageUrl": "https://lh3.googleusercontent.com/..."
    },
    "status": "ACTIVE",
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `404`  | `INVITATION_NOT_FOUND` | Invitation code does not exist |
| `410`  | `INVITATION_EXPIRED` | Invitation code has expired |
| `409`  | `COUPLE_ALREADY_EXISTS` | Accepting user is already in a couple |
| `400`  | `SELF_INVITATION` | User cannot accept their own invitation |

---

### 3. Get My Couple

Retrieves the current user's couple information including the partner's profile.

| Item        | Value                      |
|:------------|:---------------------------|
| **Method**  | `GET`                      |
| **Path**    | `/api/v1/couples/me`       |
| **Auth**    | Required                   |

**Request Body**: None

**Response `200 OK`**: `ApiResponse<CoupleResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "partner": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "홍길동",
      "profileImageUrl": "https://lh3.googleusercontent.com/..."
    },
    "status": "ACTIVE",
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `404 Not Found`**: `ApiResponse<null>` — user is not in a couple

```json
{
  "success": false,
  "data": null,
  "error": {
    "code": "COUPLE_NOT_FOUND",
    "message": "User is not currently in a couple."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 4. Dissolve Couple

Dissolves the current user's couple. All shared data (transactions, categories) is retained but no longer shared.

| Item        | Value                      |
|:------------|:---------------------------|
| **Method**  | `DELETE`                   |
| **Path**    | `/api/v1/couples/me`       |
| **Auth**    | Required                   |

**Request Body**: None

**Response `204 No Content`**: Success

**Response `404 Not Found`**: `ApiResponse<null>` — user is not in an active couple

---

## Categories

Base path: `/api/v1/categories`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. List Categories

Retrieves all categories for the caller's couple.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `GET`                        |
| **Path**    | `/api/v1/categories`         |
| **Auth**    | Required                     |

**Query Parameters**

| Parameter | Type     | Required | Description                          |
|:----------|:---------|:--------:|:-------------------------------------|
| `type`    | `string` | No       | Filter by type: `INCOME` or `EXPENSE` |

**Response `200 OK`**: `ApiResponse<List<CategoryResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "식비",
      "type": "EXPENSE",
      "icon": "restaurant",
      "color": "#FF5733",
      "isDefault": true,
      "displayOrder": 1,
      "createdAt": "2024-01-01T12:00:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440011",
      "name": "급여",
      "type": "INCOME",
      "icon": "payments",
      "color": "#4CAF50",
      "isDefault": true,
      "displayOrder": 1,
      "createdAt": "2024-01-01T12:00:00Z"
    }
  ],
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 2. Create Category

Creates a new custom category for the caller's couple.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `POST`                       |
| **Path**    | `/api/v1/categories`         |
| **Auth**    | Required                     |

**Request Body**

```json
{
  "name": "반려동물",
  "type": "EXPENSE",
  "icon": "pets",
  "color": "#9C27B0"
}
```

| Field    | Type     | Required | Description                        |
|:---------|:---------|:--------:|:-----------------------------------|
| `name`   | `string` | Yes      | Category name (max 50 chars)       |
| `type`   | `string` | Yes      | `INCOME` or `EXPENSE`              |
| `icon`   | `string` | No       | Material icon name                 |
| `color`  | `string` | No       | Hex color code (e.g., `#FF5733`)   |

**Response `201 Created`**: `ApiResponse<CategoryResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440020",
    "name": "반려동물",
    "type": "EXPENSE",
    "icon": "pets",
    "color": "#9C27B0",
    "isDefault": false,
    "displayOrder": 10,
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "error": null,
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `400`  | `VALIDATION_ERROR` | Invalid name, type, or color format |
| `404`  | `COUPLE_NOT_FOUND` | User is not in an active couple |

---

### 3. Update Category

Updates an existing category. Default categories cannot have their `type` changed.

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `PUT`                            |
| **Path**    | `/api/v1/categories/{id}`        |
| **Auth**    | Required                         |

**Path Parameters**

| Parameter | Type   | Required | Description       |
|:----------|:-------|:--------:|:------------------|
| `id`      | `UUID` | Yes      | Category ID       |

**Request Body**

```json
{
  "name": "식비/외식",
  "icon": "restaurant_menu",
  "color": "#E91E63",
  "displayOrder": 2
}
```

| Field          | Type      | Required | Description                      |
|:---------------|:----------|:--------:|:---------------------------------|
| `name`         | `string`  | No       | Updated name (max 50 chars)      |
| `icon`         | `string`  | No       | Updated icon name                |
| `color`        | `string`  | No       | Updated hex color                |
| `displayOrder` | `integer` | No       | Sort order within type group     |

**Response `200 OK`**: `ApiResponse<CategoryResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Category belongs to a different couple |
| `404`  | `CATEGORY_NOT_FOUND` | Category does not exist |

---

### 4. Delete Category

Deletes a custom category. Default categories cannot be deleted. Transactions with this category will have `category_id` set to null.

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `DELETE`                         |
| **Path**    | `/api/v1/categories/{id}`        |
| **Auth**    | Required                         |

**Path Parameters**

| Parameter | Type   | Required | Description  |
|:----------|:-------|:--------:|:-------------|
| `id`      | `UUID` | Yes      | Category ID  |

**Response `204 No Content`**: Success

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `400`  | `CANNOT_DELETE_DEFAULT_CATEGORY` | Default categories cannot be deleted |
| `403`  | `FORBIDDEN` | Category belongs to a different couple |
| `404`  | `CATEGORY_NOT_FOUND` | Category does not exist |

---

## Transactions

Base path: `/api/v1/transactions`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. List Transactions

Retrieves paginated transactions for the caller's couple. Default sort: `transaction_date DESC`, then `created_at DESC`.

| Item        | Value                          |
|:------------|:-------------------------------|
| **Method**  | `GET`                          |
| **Path**    | `/api/v1/transactions`         |
| **Auth**    | Required                       |

**Query Parameters**

| Parameter    | Type      | Required | Default | Description                          |
|:-------------|:----------|:--------:|:--------|:-------------------------------------|
| `year`       | `integer` | No       | Current | Filter by year (e.g., `2024`)        |
| `month`      | `integer` | No       | Current | Filter by month (1–12)               |
| `type`       | `string`  | No       | All     | `INCOME` or `EXPENSE`                |
| `categoryId` | `UUID`    | No       | All     | Filter by category                   |
| `page`       | `integer` | No       | `0`     | Zero-based page number               |
| `size`       | `integer` | No       | `20`    | Page size (max 100)                  |

**Response `200 OK`**: `ApiResponse<PageResponse<TransactionResponse>>`

```json
{
  "success": true,
  "data": {
    "content": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440030",
        "coupleId": "550e8400-e29b-41d4-a716-446655440001",
        "author": {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "nickname": "홍길동",
          "profileImageUrl": "https://lh3.googleusercontent.com/..."
        },
        "category": {
          "id": "550e8400-e29b-41d4-a716-446655440010",
          "name": "식비",
          "type": "EXPENSE",
          "icon": "restaurant",
          "color": "#FF5733"
        },
        "type": "EXPENSE",
        "amount": 15000,
        "description": "점심 식사",
        "memo": null,
        "transactionDate": "2024-01-15",
        "createdAt": "2024-01-15T12:30:00Z",
        "updatedAt": "2024-01-15T12:30:00Z"
      }
    ],
    "page": 0,
    "size": 20,
    "totalElements": 42,
    "totalPages": 3,
    "first": true,
    "last": false
  },
  "error": null,
  "timestamp": "2024-01-15T12:00:00Z"
}
```

---

### 2. Create Transaction

Creates a new income or expense transaction.

| Item        | Value                          |
|:------------|:-------------------------------|
| **Method**  | `POST`                         |
| **Path**    | `/api/v1/transactions`         |
| **Auth**    | Required                       |

**Request Body**

```json
{
  "type": "EXPENSE",
  "amount": 15000,
  "description": "점심 식사",
  "categoryId": "550e8400-e29b-41d4-a716-446655440010",
  "transactionDate": "2024-01-15",
  "memo": "팀 점심"
}
```

| Field             | Type     | Required | Description                           |
|:------------------|:---------|:--------:|:--------------------------------------|
| `type`            | `string` | Yes      | `INCOME` or `EXPENSE`                 |
| `amount`          | `long`   | Yes      | Amount in KRW (must be > 0)           |
| `description`     | `string` | Yes      | Short description (max 255 chars)     |
| `categoryId`      | `UUID`   | No       | Category ID (must belong to couple)   |
| `transactionDate` | `string` | Yes      | ISO 8601 date: `YYYY-MM-DD`           |
| `memo`            | `string` | No       | Optional longer note                  |

**Response `201 Created`**: `ApiResponse<TransactionResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440030",
    "coupleId": "550e8400-e29b-41d4-a716-446655440001",
    "author": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "홍길동",
      "profileImageUrl": "https://lh3.googleusercontent.com/..."
    },
    "category": {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "식비",
      "type": "EXPENSE",
      "icon": "restaurant",
      "color": "#FF5733"
    },
    "type": "EXPENSE",
    "amount": 15000,
    "description": "점심 식사",
    "memo": "팀 점심",
    "transactionDate": "2024-01-15",
    "createdAt": "2024-01-15T12:30:00Z",
    "updatedAt": "2024-01-15T12:30:00Z"
  },
  "error": null,
  "timestamp": "2024-01-15T12:30:00Z"
}
```

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `400`  | `VALIDATION_ERROR` | Invalid field values |
| `403`  | `FORBIDDEN` | Category belongs to a different couple |
| `404`  | `COUPLE_NOT_FOUND` | User is not in an active couple |
| `404`  | `CATEGORY_NOT_FOUND` | Specified category does not exist |

---

### 3. Get Transaction

Retrieves a single transaction by ID. Caller must be a member of the couple that owns the transaction.

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `GET`                              |
| **Path**    | `/api/v1/transactions/{id}`        |
| **Auth**    | Required                           |

**Path Parameters**

| Parameter | Type   | Required | Description       |
|:----------|:-------|:--------:|:------------------|
| `id`      | `UUID` | Yes      | Transaction ID    |

**Response `200 OK`**: `ApiResponse<TransactionResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Transaction belongs to a different couple |
| `404`  | `TRANSACTION_NOT_FOUND` | Transaction does not exist |

---

### 4. Update Transaction

Updates an existing transaction. Only the author or the partner can update it.

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `PUT`                              |
| **Path**    | `/api/v1/transactions/{id}`        |
| **Auth**    | Required                           |

**Path Parameters**

| Parameter | Type   | Required | Description    |
|:----------|:-------|:--------:|:---------------|
| `id`      | `UUID` | Yes      | Transaction ID |

**Request Body**

```json
{
  "amount": 18000,
  "description": "점심 + 커피",
  "categoryId": "550e8400-e29b-41d4-a716-446655440010",
  "transactionDate": "2024-01-15",
  "memo": null
}
```

| Field             | Type     | Required | Description                         |
|:------------------|:---------|:--------:|:------------------------------------|
| `amount`          | `long`   | No       | Updated amount (must be > 0)        |
| `description`     | `string` | No       | Updated description (max 255 chars) |
| `categoryId`      | `UUID`   | No       | Updated category (null to unset)    |
| `transactionDate` | `string` | No       | Updated date: `YYYY-MM-DD`          |
| `memo`            | `string` | No       | Updated memo (null to clear)        |

**Response `200 OK`**: `ApiResponse<TransactionResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Transaction belongs to a different couple |
| `404`  | `TRANSACTION_NOT_FOUND` | Transaction does not exist |

---

### 5. Delete Transaction

Permanently deletes a transaction. Only the author or the partner can delete it.

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `DELETE`                           |
| **Path**    | `/api/v1/transactions/{id}`        |
| **Auth**    | Required                           |

**Path Parameters**

| Parameter | Type   | Required | Description    |
|:----------|:-------|:--------:|:---------------|
| `id`      | `UUID` | Yes      | Transaction ID |

**Response `204 No Content`**: Success

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Transaction belongs to a different couple |
| `404`  | `TRANSACTION_NOT_FOUND` | Transaction does not exist |

---

## Common Data Types

### TokenResponse

| Field          | Type     | Description                                |
|:---------------|:---------|:-------------------------------------------|
| `accessToken`  | `string` | JWT access token                           |
| `refreshToken` | `string` | Opaque refresh token                       |
| `expiresIn`    | `number` | Access token TTL in seconds (default: 3600)|

### UserResponse

| Field             | Type      | Nullable | Description                      |
|:------------------|:----------|:--------:|:---------------------------------|
| `id`              | `UUID`    | No       | User unique identifier           |
| `email`           | `string`  | No       | User email address               |
| `nickname`        | `string`  | No       | Display name                     |
| `profileImageUrl` | `string`  | Yes      | Profile image URL from provider  |
| `provider`        | `enum`    | No       | `GOOGLE` or `KAKAO`             |
| `role`            | `enum`    | No       | `USER` or `ADMIN`               |
| `coupleId`        | `UUID`    | Yes      | Active couple ID (null if not linked) |
| `createdAt`       | `string`  | No       | ISO 8601 timestamp               |

### InvitationResponse

| Field       | Type     | Nullable | Description                     |
|:------------|:---------|:--------:|:--------------------------------|
| `code`      | `string` | No       | 8-character alphanumeric code   |
| `expiresAt` | `string` | No       | ISO 8601 expiry timestamp (24h) |

### CoupleResponse

| Field       | Type              | Nullable | Description                         |
|:------------|:------------------|:--------:|:------------------------------------|
| `id`        | `UUID`            | No       | Couple unique identifier            |
| `partner`   | `UserSummary`     | No       | Partner's profile                   |
| `status`    | `enum`            | No       | `ACTIVE` or `DISSOLVED`             |
| `createdAt` | `string`          | No       | ISO 8601 timestamp                  |

### UserSummary

| Field             | Type     | Nullable | Description                      |
|:------------------|:---------|:--------:|:---------------------------------|
| `id`              | `UUID`   | No       | User unique identifier           |
| `nickname`        | `string` | No       | Display name                     |
| `profileImageUrl` | `string` | Yes      | Profile image URL from provider  |

### CategoryResponse

| Field          | Type      | Nullable | Description                          |
|:---------------|:----------|:--------:|:-------------------------------------|
| `id`           | `UUID`    | No       | Category unique identifier           |
| `name`         | `string`  | No       | Category name                        |
| `type`         | `enum`    | No       | `INCOME` or `EXPENSE`                |
| `icon`         | `string`  | Yes      | Material icon name                   |
| `color`        | `string`  | Yes      | Hex color code (e.g., `#FF5733`)     |
| `isDefault`    | `boolean` | No       | Whether this is a system default     |
| `displayOrder` | `integer` | No       | Sort order within type group         |
| `createdAt`    | `string`  | No       | ISO 8601 timestamp                   |

### CategorySummary

| Field   | Type     | Nullable | Description         |
|:--------|:---------|:--------:|:--------------------|
| `id`    | `UUID`   | No       | Category ID         |
| `name`  | `string` | No       | Category name       |
| `type`  | `enum`   | No       | `INCOME` or `EXPENSE` |
| `icon`  | `string` | Yes      | Material icon name  |
| `color` | `string` | Yes      | Hex color code      |

### TransactionResponse

| Field             | Type              | Nullable | Description                      |
|:------------------|:------------------|:--------:|:---------------------------------|
| `id`              | `UUID`            | No       | Transaction unique identifier    |
| `coupleId`        | `UUID`            | No       | Owning couple ID                 |
| `author`          | `UserSummary`     | No       | User who recorded the transaction|
| `category`        | `CategorySummary` | Yes      | Category (null if uncategorized) |
| `type`            | `enum`            | No       | `INCOME` or `EXPENSE`            |
| `amount`          | `long`            | No       | Amount in KRW (always > 0)       |
| `description`     | `string`          | No       | Short description                |
| `memo`            | `string`          | Yes      | Optional longer note             |
| `transactionDate` | `string`          | No       | ISO 8601 date: `YYYY-MM-DD`      |
| `createdAt`       | `string`          | No       | ISO 8601 timestamp               |
| `updatedAt`       | `string`          | No       | ISO 8601 timestamp               |

### PageResponse\<T\>

| Field           | Type      | Description                            |
|:----------------|:----------|:---------------------------------------|
| `content`       | `array`   | List of items on this page             |
| `page`          | `integer` | Current page number (zero-based)       |
| `size`          | `integer` | Page size requested                    |
| `totalElements` | `long`    | Total number of matching records       |
| `totalPages`    | `integer` | Total number of pages                  |
| `first`         | `boolean` | Whether this is the first page         |
| `last`          | `boolean` | Whether this is the last page          |

---

## Error Codes

| Error Code                        | HTTP Status | Description                                          |
|:----------------------------------|:-----------:|:-----------------------------------------------------|
| `AUTH_FAILED`                     | `401`       | Authentication failed (invalid credentials)          |
| `INVALID_TOKEN`                   | `401`       | Access token is invalid or malformed                 |
| `INVALID_REFRESH_TOKEN`           | `401`       | Refresh token is invalid, expired, or revoked        |
| `TOKEN_EXPIRED`                   | `401`       | Access token has expired (client should refresh)     |
| `USER_NOT_FOUND`                  | `404`       | Requested user does not exist                        |
| `VALIDATION_ERROR`                | `400`       | Request body validation failed                       |
| `DUPLICATE_RESOURCE`              | `409`       | Resource already exists (e.g., duplicate email)      |
| `FORBIDDEN`                       | `403`       | Authenticated but insufficient permissions           |
| `INTERNAL_ERROR`                  | `500`       | Unexpected server error                              |
| `PROVIDER_AUTH_FAILED`            | `401`       | OAuth provider authentication/callback failed        |
| `UNSUPPORTED_PROVIDER`            | `400`       | Requested OAuth provider is not supported            |
| `COUPLE_NOT_FOUND`                | `404`       | User is not currently in an active couple            |
| `COUPLE_ALREADY_EXISTS`           | `409`       | User is already in an active couple                  |
| `INVITATION_NOT_FOUND`            | `404`       | Invitation code does not exist                       |
| `INVITATION_EXPIRED`              | `410`       | Invitation code has expired                          |
| `SELF_INVITATION`                 | `400`       | User cannot accept their own invitation              |
| `CATEGORY_NOT_FOUND`              | `404`       | Requested category does not exist                    |
| `CANNOT_DELETE_DEFAULT_CATEGORY`  | `400`       | Default (system) categories cannot be deleted        |
| `TRANSACTION_NOT_FOUND`           | `404`       | Requested transaction does not exist                 |
