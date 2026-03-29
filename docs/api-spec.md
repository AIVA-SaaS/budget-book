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
  - [Update Profile](#4-update-profile)
  - [Logout](#5-logout)
- [Couple](#couple)
  - [Create Invitation Code](#1-create-invitation-code)
  - [Get My Invitation Status](#2-get-my-invitation-status)
  - [Accept Invitation](#3-accept-invitation)
  - [Get My Couple](#4-get-my-couple)
  - [Dissolve Couple](#5-dissolve-couple)
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
  - [Export CSV](#6-export-csv)
- [Budgets](#budgets)
  - [Create Budget](#1-create-budget)
  - [List Budgets](#2-list-budgets)
  - [Update Budget](#3-update-budget)
  - [Delete Budget](#4-delete-budget)
  - [Budget Summary](#5-budget-summary)
  - [Copy Previous Month](#6-copy-previous-month)
- [Statistics](#statistics)
  - [Monthly Summary](#1-monthly-summary)
  - [Category Breakdown](#2-category-breakdown)
  - [Monthly Trend](#3-monthly-trend)
- [Category Groups](#category-groups)
  - [List Category Groups](#1-list-category-groups)
  - [Create Category Group](#2-create-category-group)
  - [Update Category Group](#3-update-category-group)
  - [Delete Category Group](#4-delete-category-group)
  - [Reorder Category Groups](#5-reorder-category-groups)
- [Payment Methods](#payment-methods)
  - [List Payment Methods](#1-list-payment-methods)
  - [Create Payment Method](#2-create-payment-method)
  - [Update Payment Method](#3-update-payment-method)
  - [Delete Payment Method](#4-delete-payment-method)
  - [Card Pending Summary](#5-card-pending-summary)
  - [Card Settlement Summary](#6-card-settlement-summary)
- [Weekly Budgets](#weekly-budgets)
  - [Weekly Overview](#1-weekly-overview)
  - [Current Week Summary](#2-current-week-summary)
- [Reports](#reports)
  - [Weekly Report](#1-weekly-report)
  - [Monthly Report](#2-monthly-report)
- [Recurring Transactions](#recurring-transactions)
  - [List Recurring Transactions](#1-list-recurring-transactions)
  - [Create Recurring Transaction](#2-create-recurring-transaction)
  - [Update Recurring Transaction](#3-update-recurring-transaction)
  - [Delete Recurring Transaction](#4-delete-recurring-transaction)
- [Money Pockets](#money-pockets)
  - [List Pockets](#1-list-pockets)
  - [Create Pocket](#2-create-pocket)
  - [Update Pocket](#3-update-pocket)
  - [Delete Pocket](#4-delete-pocket)
  - [Get Distribution Ratios](#5-get-distribution-ratios)
  - [Save Distribution Ratios](#6-save-distribution-ratios)
  - [Pocket Summary](#5-pocket-summary)
  - [Distribute Income](#6-distribute-income)
- [Pocket Transfers](#pocket-transfers)
  - [List Pocket Transfers](#1-list-pocket-transfers)
  - [Create Pocket Transfer](#2-create-pocket-transfer)
- [Transfers](#transfers)
  - [Create Transfer](#1-create-transfer)
  - [List Transfers](#2-list-transfers)
  - [Get Transfer](#3-get-transfer)
  - [Update Transfer](#4-update-transfer)
  - [Delete Transfer](#5-delete-transfer)
- [Insurances](#insurances)
  - [List Insurances](#1-list-insurances)
  - [Create Insurance](#2-create-insurance)
  - [Update Insurance](#3-update-insurance)
  - [Delete Insurance](#4-delete-insurance)
  - [Insurance Summary](#5-insurance-summary)
- [Preferences (Favorites)](#preferences-favorites)
  - [Get Favorites](#1-get-favorites)
  - [Update Favorites](#2-update-favorites)
  - [Toggle Favorite](#3-toggle-favorite)
- [Spending Plans](#spending-plans)
  - [List Spending Plans](#1-list-spending-plans)
  - [Create Spending Plan](#2-create-spending-plan)
  - [Update Spending Plan](#3-update-spending-plan)
  - [Delete Spending Plan](#4-delete-spending-plan)
  - [Complete Spending Plan](#5-complete-spending-plan)
  - [Skip Spending Plan](#6-skip-spending-plan)
  - [Spending Plan Suggestions](#7-spending-plan-suggestions)
  - [List Wishlist](#8-list-wishlist)
  - [Assign Spending Plan](#9-assign-spending-plan)
  - [Complete with Transaction](#10-complete-with-transaction)
- [Infrastructure](#infrastructure)
  - [Health Check](#1-health-check)
  - [Actuator Health](#2-actuator-health)
- [WebSocket (STOMP)](#websocket-stomp)
  - [Connection](#connection)
  - [Subscription Topics](#subscription-topics)
  - [Event Payload Schema](#event-payload-schema)
  - [Event Types](#event-types)
- [Redis Cache Strategy](#redis-cache-strategy)
- [Common Data Types](#common-data-types)
- [Error Codes](#error-codes)

---

## Common Response Format

All API responses are wrapped in `ApiResponse<T>`:

```json
{
  "success": true,
  "data": T,
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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Error response** (`success: false`):

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message"
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

> **Note on null fields**: The API uses `@JsonInclude(NON_NULL)`. Fields that are `null` are **omitted entirely** from the JSON response rather than serialized as `"field": null`. For example, a success response will not include an `"error"` key, and an error response will not include a `"data"` key.

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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

Note: `coupleId` is omitted from the response when the user is not in an active couple (NON_NULL serialization). This allows the frontend to decide routing immediately after login.

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
  "error": {
    "code": "INVALID_TOKEN",
    "message": "The access token is invalid or has expired."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 4. Update Profile

Updates the current user's profile information (nickname, profile image).

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `PATCH`                      |
| **Path**    | `/api/v1/auth/me`            |
| **Auth**    | Required                     |

**Headers**

| Header          | Value                    | Required |
|:----------------|:-------------------------|:--------:|
| `Authorization` | `Bearer {accessToken}`   | Yes      |
| `Content-Type`  | `application/json`       | Yes      |

**Request Body**

| Field               | Type      | Required | Description                        |
|:--------------------|:----------|:--------:|:-----------------------------------|
| `nickname`          | `string`  | No       | New nickname (1-50 chars)          |
| `profileImageUrl`   | `string`  | No       | New profile image URL              |
| `clearProfileImage` | `boolean` | No       | Set true to remove profile image   |

```json
{
  "nickname": "새닉네임",
  "profileImageUrl": null,
  "clearProfileImage": false
}
```

**Response `200 OK`**: `ApiResponse<UserResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "nickname": "새닉네임",
    "profileImageUrl": "https://lh3.googleusercontent.com/...",
    "provider": "GOOGLE",
    "role": "USER",
    "coupleId": "550e8400-e29b-41d4-a716-446655440001",
    "createdAt": "2024-01-01T12:00:00Z"
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `400 Bad Request`**: Validation error (e.g., nickname too long)

---

### 5. Logout

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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `401 Unauthorized`**: `ApiResponse<null>`

```json
{
  "success": false,
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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `409 Conflict`**: `ApiResponse<null>` — user is already in an active couple

```json
{
  "success": false,
  "error": {
    "code": "COUPLE_ALREADY_EXISTS",
    "message": "User is already in an active couple."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 2. Get My Invitation Status

Retrieves the most recent invitation issued by the current user. If the invitation is still `PENDING` but the expiry time has passed, the server automatically transitions the status to `EXPIRED` before returning.

| Item        | Value                                          |
|:------------|:-----------------------------------------------|
| **Method**  | `GET`                                          |
| **Path**    | `/api/v1/couples/invitations/me`               |
| **Auth**    | Required                                       |

**Request Body**: None

**Response `200 OK`**: `ApiResponse<InvitationStatusResponse>`

```json
{
  "success": true,
  "data": {
    "code": "ABCD1234",
    "expiresAt": "2026-03-20T12:00:00Z",
    "status": "PENDING"
  },
  "timestamp": "2026-03-19T10:00:00Z"
}
```

**DTO fields**

| Field       | Type     | Nullable | Description                                             |
|:------------|:---------|:--------:|:--------------------------------------------------------|
| `code`      | `string` | No       | 8-character alphanumeric invitation code                |
| `expiresAt` | `string` | No       | ISO 8601 expiry timestamp                               |
| `status`    | `string` | No       | `PENDING` (valid, awaiting acceptance), `EXPIRED` (time elapsed), `ACCEPTED` (already used) |

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `404`  | `INVITATION_NOT_FOUND` | No invitation exists for this user |

---

### 3. Accept Invitation

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

### 4. Get My Couple

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
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Response `404 Not Found`**: `ApiResponse<null>` — user is not in a couple

```json
{
  "success": false,
  "error": {
    "code": "COUPLE_NOT_FOUND",
    "message": "User is not currently in a couple."
  },
  "timestamp": "2024-01-01T12:00:00Z"
}
```

---

### 5. Dissolve Couple

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

| Parameter    | Type     | Required | Default | Description                                                        |
|:-------------|:---------|:--------:|:--------|:-------------------------------------------------------------------|
| `type`       | `string` | No       | All     | Filter by type: `INCOME` or `EXPENSE`                             |
| `visibility` | `string` | No       | `ALL`   | `SHARED`, `PRIVATE`, or `ALL` (SHARED + caller's own PRIVATE) |

> **Visibility filtering**: `ALL` returns all SHARED categories plus any PRIVATE categories owned by the caller. The caller never receives another member's PRIVATE categories.

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
      "groupId": "550e8400-e29b-41d4-a716-446655440060",
      "isDefault": true,
      "displayOrder": 1,
      "visibility": "SHARED",
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
      "visibility": "SHARED",
      "createdAt": "2024-01-01T12:00:00Z"
    }
  ],
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
  "color": "#9C27B0",
  "groupId": "550e8400-e29b-41d4-a716-446655440060",
  "visibility": "PRIVATE"
}
```

| Field        | Type     | Required | Description                                                   |
|:-------------|:---------|:--------:|:--------------------------------------------------------------|
| `name`       | `string` | Yes      | Category name (max 50 chars)                                  |
| `type`       | `string` | Yes      | `INCOME` or `EXPENSE`                                         |
| `icon`       | `string` | No       | Material icon name                                            |
| `color`      | `string` | No       | Hex color code (e.g., `#FF5733`)                              |
| `groupId`    | `UUID`   | No       | Category group ID (null = uncategorized)                      |
| `visibility` | `string` | No       | `SHARED` (default) or `PRIVATE`. Private categories are only visible to the creator. |

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
    "groupId": "550e8400-e29b-41d4-a716-446655440060",
    "isDefault": false,
    "displayOrder": 10,
    "visibility": "PRIVATE",
    "ownerId": "550e8400-e29b-41d4-a716-446655440000",
    "createdAt": "2024-01-01T12:00:00Z"
  },
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
  "displayOrder": 2,
  "groupId": "550e8400-e29b-41d4-a716-446655440060"
}
```

| Field          | Type      | Required | Description                              |
|:---------------|:----------|:--------:|:-----------------------------------------|
| `name`         | `string`  | No       | Updated name (max 50 chars)              |
| `icon`         | `string`  | No       | Updated icon name                        |
| `color`        | `string`  | No       | Updated hex color                        |
| `displayOrder` | `integer` | No       | Sort order within type group             |
| `groupId`      | `UUID`    | No       | Updated group ID (null = uncategorized)  |

**Response `200 OK`**: `ApiResponse<CategoryResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Category belongs to a different couple |
| `404`  | `CATEGORY_NOT_FOUND` | Category does not exist |

---

### 4. Delete Category

Deletes a category (including default categories). Transactions with this category will have `category_id` set to null.

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

| Parameter    | Type      | Required | Default | Description                                                        |
|:-------------|:----------|:--------:|:--------|:-------------------------------------------------------------------|
| `year`       | `integer` | No       | Current | Filter by year (e.g., `2024`)                                     |
| `month`      | `integer` | No       | Current | Filter by month (1–12)                                            |
| `type`       | `string`  | No       | All     | `INCOME` or `EXPENSE`                                             |
| `categoryId` | `UUID`    | No       | All     | Filter by category                                                 |
| `visibility` | `string`  | No       | `ALL`   | `SHARED`, `PRIVATE`, or `ALL` (SHARED + caller's own PRIVATE) |
| `page`       | `integer` | No       | `0`     | Zero-based page number                                            |
| `size`       | `integer` | No       | `20`    | Page size (max 100)                                               |

> **Visibility filtering**: `ALL` returns all SHARED transactions plus PRIVATE transactions owned by the caller. The caller never receives another member's PRIVATE transactions.

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
        "transactionDate": "2024-01-15",
        "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
        "paymentMethodName": "신한카드",
        "paymentMethodType": "CREDIT",
        "settlementDate": "2024-02-15",
        "visibility": "SHARED",
        "createdAt": "2024-01-15T12:30:00Z",
        "updatedAt": "2024-01-15T12:30:00Z"
      },
      {
        "id": "550e8400-e29b-41d4-a716-446655440032",
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
        "amount": 8000,
        "description": "편의점",
        "transactionDate": "2024-01-15",
        "paymentMethodId": "550e8400-e29b-41d4-a716-446655440033",
        "paymentMethodName": "현금",
        "paymentMethodType": "CASH",
        "visibility": "PRIVATE",
        "ownerId": "550e8400-e29b-41d4-a716-446655440000",
        "createdAt": "2024-01-15T14:00:00Z",
        "updatedAt": "2024-01-15T14:00:00Z"
      }
    ],
    "page": 0,
    "size": 20,
    "totalElements": 42,
    "totalPages": 3,
    "first": true,
    "last": false
  },
  "timestamp": "2024-01-15T12:00:00Z"
}
```

> **Note**: `settlementDate` is only included in the response when the payment method type is `CREDIT` and the credit card has a configured settlement day. For `CASH` and `DEBIT` transactions, this field is omitted (`@JsonInclude(NON_NULL)`).

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
  "memo": "팀 점심",
  "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
  "visibility": "SHARED"
}
```

| Field             | Type     | Required | Description                                                         |
|:------------------|:---------|:--------:|:--------------------------------------------------------------------|
| `type`            | `string` | Yes      | `INCOME` or `EXPENSE`                                               |
| `amount`          | `long`   | Yes      | Amount in KRW (must be > 0)                                         |
| `description`     | `string` | Yes      | Short description (max 255 chars)                                   |
| `categoryId`      | `UUID`   | No       | Category ID (must belong to couple)                                 |
| `transactionDate` | `string` | Yes      | ISO 8601 date: `YYYY-MM-DD`                                         |
| `memo`            | `string` | No       | Optional longer note                                                |
| `paymentMethodId` | `UUID`   | No       | Payment method ID (must belong to couple)                           |
| `visibility`      | `string` | No       | `SHARED` (default) or `PRIVATE`. Private transactions are only visible to the creator. |

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
    "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
    "paymentMethodName": "신한카드",
    "paymentMethodType": "CREDIT",
    "visibility": "SHARED",
    "createdAt": "2024-01-15T12:30:00Z",
    "updatedAt": "2024-01-15T12:30:00Z"
  },
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
  "memo": null,
  "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
  "visibility": "SHARED"
}
```

| Field             | Type     | Required | Description                                                    |
|:------------------|:---------|:--------:|:---------------------------------------------------------------|
| `amount`          | `long`   | No       | Updated amount (must be > 0)                                   |
| `description`     | `string` | No       | Updated description (max 255 chars)                            |
| `categoryId`      | `UUID`   | No       | Updated category (null to unset)                               |
| `transactionDate` | `string` | No       | Updated date: `YYYY-MM-DD`                                     |
| `memo`            | `string` | No       | Updated memo (null to clear)                                   |
| `paymentMethodId` | `UUID`   | No       | Updated payment method (null to unset)                         |
| `visibility`      | `string` | No       | `SHARED` or `PRIVATE`. Only the owner can change this field.   |

**Response `200 OK`**: `ApiResponse<TransactionResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Transaction belongs to a different couple |
| `403`  | `PRIVATE_ACCESS_DENIED` | Transaction is PRIVATE and caller is not the owner |
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

## Budgets

Base path: `/api/v1/budgets`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. Create Budget

Creates a monthly budget for the couple. At most one of `categoryId` or `groupId` may be set. If both are `null`, the entry represents the total (uncategorized) monthly budget.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `POST`                       |
| **Path**    | `/api/v1/budgets`            |
| **Auth**    | Required                     |

**Request Body**

```json
{
  "categoryId": "550e8400-e29b-41d4-a716-446655440010",
  "groupId": null,
  "yearMonth": "2026-03",
  "amount": 150000,
  "budgetPeriod": "MONTHLY",
  "visibility": "SHARED"
}
```

| Field          | Type     | Required | Description                                                                                          |
|:---------------|:---------|:--------:|:-----------------------------------------------------------------------------------------------------|
| `categoryId`   | `UUID`   | No       | Category ID. Mutually exclusive with `groupId`. Both `null` = total budget for the month.            |
| `groupId`      | `UUID`   | No       | Category group ID. Mutually exclusive with `categoryId`. Both `null` = total budget for the month.   |
| `yearMonth`    | `string` | Yes      | Target month in `YYYY-MM` format (e.g., `2026-03`)                                                  |
| `amount`       | `long`   | Yes      | Budget amount in KRW (must be > 0)                                                                   |
| `budgetPeriod` | `string` | No       | Budget period type: `MONTHLY` (default) or `WEEKLY`                                                  |
| `visibility`   | `string` | No       | `SHARED` (default) or `PRIVATE`. Private budgets are only visible to the creator. Shared and private budgets can coexist for the same category/month (unique constraint applies per visibility scope). |

**Response `201 Created`**: `ApiResponse<BudgetResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440050",
    "coupleId": "550e8400-e29b-41d4-a716-446655440001",
    "category": {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "식비",
      "type": "EXPENSE",
      "icon": "restaurant",
      "color": "#FF5733"
    },
    "groupId": null,
    "groupName": null,
    "yearMonth": "2026-03",
    "amount": 150000,
    "budgetPeriod": "MONTHLY",
    "visibility": "SHARED",
    "createdAt": "2026-03-01T12:00:00Z",
    "updatedAt": "2026-03-01T12:00:00Z"
  },
  "timestamp": "2026-03-01T12:00:00Z"
}
```

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `400`  | `VALIDATION_ERROR` | Invalid field values or both `categoryId` and `groupId` are set |
| `404`  | `CATEGORY_NOT_FOUND` | Specified category does not exist |
| `404`  | `GROUP_NOT_FOUND` | Specified category group does not exist |
| `409`  | `DUPLICATE_BUDGET` | Budget for this category/group, month, and visibility already exists |

---

### 2. List Budgets

Retrieves all budgets for the couple for a given month.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `GET`                        |
| **Path**    | `/api/v1/budgets`            |
| **Auth**    | Required                     |

**Query Parameters**

| Parameter    | Type      | Required | Default | Description                                                        |
|:-------------|:----------|:--------:|:--------|:-------------------------------------------------------------------|
| `year`       | `integer` | Yes      | —       | Target year (e.g., `2026`)                                        |
| `month`      | `integer` | Yes      | —       | Target month (1–12)                                               |
| `visibility` | `string`  | No       | `ALL`   | `SHARED`, `PRIVATE`, or `ALL` (SHARED + caller's own PRIVATE) |

**Response `200 OK`**: `ApiResponse<List<BudgetResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440050",
      "coupleId": "550e8400-e29b-41d4-a716-446655440001",
      "category": {
        "id": "550e8400-e29b-41d4-a716-446655440010",
        "name": "식비",
        "type": "EXPENSE",
        "icon": "restaurant",
        "color": "#FF5733"
      },
      "groupId": null,
      "groupName": null,
      "yearMonth": "2026-03",
      "amount": 150000,
      "budgetPeriod": "MONTHLY",
      "visibility": "SHARED",
      "createdAt": "2026-03-01T12:00:00Z",
      "updatedAt": "2026-03-01T12:00:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440051",
      "coupleId": "550e8400-e29b-41d4-a716-446655440001",
      "groupId": "550e8400-e29b-41d4-a716-446655440010",
      "groupName": "생활비",
      "yearMonth": "2026-03",
      "amount": 800000,
      "budgetPeriod": "WEEKLY",
      "weeklyAmount": 200000,
      "visibility": "PRIVATE",
      "ownerId": "550e8400-e29b-41d4-a716-446655440000",
      "createdAt": "2026-03-01T12:00:00Z",
      "updatedAt": "2026-03-01T12:00:00Z"
    }
  ],
  "timestamp": "2026-03-01T12:00:00Z"
}
```

---

### 3. Update Budget

Updates an existing budget's amount, period type, or weekly amount.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `PUT`                        |
| **Path**    | `/api/v1/budgets/{id}`       |
| **Auth**    | Required                     |

**Path Parameters**

| Parameter | Type   | Required | Description  |
|:----------|:-------|:--------:|:-------------|
| `id`      | `UUID` | Yes      | Budget ID    |

**Request Body**

```json
{
  "categoryId": null,
  "groupId": "550e8400-e29b-41d4-a716-446655440010",
  "amount": 200000,
  "budgetPeriod": "WEEKLY",
  "weeklyAmount": 50000,
  "visibility": "SHARED"
}
```

| Field          | Type     | Required | Description                                                                 |
|:---------------|:---------|:--------:|:----------------------------------------------------------------------------|
| `categoryId`   | `UUID`   | No       | Category ID. Mutually exclusive with `groupId`. Omit to preserve existing value. |
| `groupId`      | `UUID`   | No       | Category group ID. Mutually exclusive with `categoryId`. Omit to preserve existing value. |
| `amount`       | `long`   | Yes      | Updated budget amount (must be > 0)                                         |
| `budgetPeriod` | `string` | No       | `MONTHLY` or `WEEKLY`. If omitted, existing value is preserved.             |
| `weeklyAmount` | `long`   | No       | Per-week amount in KRW. Only relevant when `budgetPeriod` is `WEEKLY`. If omitted when switching to `WEEKLY`, it is auto-calculated from `amount`. |
| `visibility`   | `string` | No       | `SHARED` or `PRIVATE`. Only the owner can change this field.                |

**Response `200 OK`**: `ApiResponse<BudgetResponse>`

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `400`  | `VALIDATION_ERROR` | Invalid amount or budgetPeriod value |
| `403`  | `FORBIDDEN` | Budget belongs to a different couple |
| `404`  | `BUDGET_NOT_FOUND` | Budget does not exist |

---

### 4. Delete Budget

Permanently deletes a budget entry.

| Item        | Value                        |
|:------------|:-----------------------------|
| **Method**  | `DELETE`                     |
| **Path**    | `/api/v1/budgets/{id}`       |
| **Auth**    | Required                     |

**Path Parameters**

| Parameter | Type   | Required | Description  |
|:----------|:-------|:--------:|:-------------|
| `id`      | `UUID` | Yes      | Budget ID    |

**Response `204 No Content`**: Success

**Error Responses**

| Status | Error Code | Description |
|:-------|:-----------|:------------|
| `403`  | `FORBIDDEN` | Budget belongs to a different couple |
| `404`  | `BUDGET_NOT_FOUND` | Budget does not exist |

---

### 5. Budget Summary

Returns per-category budget vs actual spending summary for a given month.

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `GET`                            |
| **Path**    | `/api/v1/budgets/summary`        |
| **Auth**    | Required                         |

**Query Parameters**

| Parameter | Type      | Required | Description              |
|:----------|:----------|:--------:|:-------------------------|
| `year`    | `integer` | Yes      | Target year (e.g., `2026`) |
| `month`   | `integer` | Yes      | Target month (1–12)      |

**Response `200 OK`**: `ApiResponse<BudgetSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "yearMonth": "2026-03",
    "totalBudget": 3150000,
    "totalSpent": 1800000,
    "items": [
      {
        "category": {
          "id": "550e8400-e29b-41d4-a716-446655440010",
          "name": "식비",
          "type": "EXPENSE",
          "icon": "restaurant",
          "color": "#FF5733"
        },
        "budgetAmount": 150000,
        "spentAmount": 95000,
        "remainingAmount": 55000,
        "usageRate": 63.3
      },
      {
        "budgetAmount": 3000000,
        "spentAmount": 1705000,
        "remainingAmount": 1295000,
        "usageRate": 56.8
      }
    ]
  },
  "timestamp": "2026-03-01T12:00:00Z"
}
```

---

## Statistics

Base path: `/api/v1/statistics`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. Monthly Summary

Returns total income, total expense, balance, and transaction count for a given month.

| Item        | Value                               |
|:------------|:------------------------------------|
| **Method**  | `GET`                               |
| **Path**    | `/api/v1/statistics/summary`        |
| **Auth**    | Required                            |

**Query Parameters**

| Parameter    | Type      | Required | Default | Description                                                        |
|:-------------|:----------|:--------:|:--------|:-------------------------------------------------------------------|
| `year`       | `integer` | Yes      | —       | Target year (e.g., `2026`)                                        |
| `month`      | `integer` | Yes      | —       | Target month (1–12)                                               |
| `visibility` | `string`  | No       | `ALL`   | `SHARED`, `PRIVATE`, or `ALL` (SHARED + caller's own PRIVATE). Determines which transactions are included in the summary totals. |

**Response `200 OK`**: `ApiResponse<StatisticsSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "yearMonth": "2026-03",
    "totalIncome": 5000000,
    "totalExpense": 3200000,
    "balance": 1800000,
    "transactionCount": 45
  },
  "timestamp": "2026-03-01T12:00:00Z"
}
```

---

### 2. Category Breakdown

Returns spending (or income) broken down by category for a given month, sorted by amount descending.

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/api/v1/statistics/by-category`         |
| **Auth**    | Required                                 |

**Query Parameters**

| Parameter    | Type      | Required | Default   | Description                                                        |
|:-------------|:----------|:--------:|:----------|:-------------------------------------------------------------------|
| `year`       | `integer` | Yes      | —         | Target year (e.g., `2026`)                                        |
| `month`      | `integer` | Yes      | —         | Target month (1–12)                                               |
| `type`       | `string`  | No       | `EXPENSE` | `INCOME` or `EXPENSE`                                             |
| `visibility` | `string`  | No       | `ALL`     | `SHARED`, `PRIVATE`, or `ALL` (SHARED + caller's own PRIVATE) |

**Response `200 OK`**: `ApiResponse<List<CategoryStatisticsResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "category": {
        "id": "550e8400-e29b-41d4-a716-446655440010",
        "name": "식비",
        "type": "EXPENSE",
        "icon": "restaurant",
        "color": "#FF5733"
      },
      "amount": 800000,
      "percentage": 25.0,
      "transactionCount": 12
    },
    {
      "category": {
        "id": "550e8400-e29b-41d4-a716-446655440011",
        "name": "교통비",
        "type": "EXPENSE",
        "icon": "directions_car",
        "color": "#2196F3"
      },
      "amount": 320000,
      "percentage": 10.0,
      "transactionCount": 8
    }
  ],
  "timestamp": "2026-03-01T12:00:00Z"
}
```

---

### 3. Monthly Trend

Returns month-over-month income, expense, and balance for the last N months including the current month, ordered chronologically.

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/api/v1/statistics/monthly-trend`       |
| **Auth**    | Required                                 |

**Query Parameters**

| Parameter | Type      | Required | Default | Description                                   |
|:----------|:----------|:--------:|:--------|:----------------------------------------------|
| `months`  | `integer` | No       | `6`     | Number of months to include (min 1, max 24)   |

**Response `200 OK`**: `ApiResponse<List<MonthlyTrendResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "yearMonth": "2025-10",
      "totalIncome": 4500000,
      "totalExpense": 3100000,
      "balance": 1400000
    },
    {
      "yearMonth": "2025-11",
      "totalIncome": 4800000,
      "totalExpense": 3400000,
      "balance": 1400000
    },
    {
      "yearMonth": "2025-12",
      "totalIncome": 5200000,
      "totalExpense": 4100000,
      "balance": 1100000
    },
    {
      "yearMonth": "2026-01",
      "totalIncome": 5000000,
      "totalExpense": 3200000,
      "balance": 1800000
    },
    {
      "yearMonth": "2026-02",
      "totalIncome": 4900000,
      "totalExpense": 3050000,
      "balance": 1850000
    },
    {
      "yearMonth": "2026-03",
      "totalIncome": 5000000,
      "totalExpense": 3200000,
      "balance": 1800000
    }
  ],
  "timestamp": "2026-03-01T12:00:00Z"
}
```

---

## Category Groups

Base path: `/api/v1/category-groups`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. List Category Groups

Retrieves all category groups with their nested categories. Includes a virtual "미분류" group for categories without a group.

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `GET`                            |
| **Path**    | `/api/v1/category-groups`        |
| **Auth**    | Required                         |

**Response `200 OK`**: `ApiResponse<List<CategoryGroupResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "생활비",
      "icon": "account_balance_wallet",
      "color": "#4CAF50",
      "budgetType": "WEEKLY",
      "displayOrder": 1,
      "isDefault": true,
      "categories": [
        {
          "id": "550e8400-e29b-41d4-a716-446655440020",
          "name": "식비",
          "type": "EXPENSE",
          "icon": "restaurant",
          "color": "#FF5733",
          "isDefault": true,
          "displayOrder": 1,
          "groupId": "550e8400-e29b-41d4-a716-446655440010",
          "createdAt": "2024-01-01T12:00:00Z"
        }
      ],
      "createdAt": "2024-01-01T12:00:00Z"
    }
  ]
}
```

---

### 2. Create Category Group

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `POST`                           |
| **Path**    | `/api/v1/category-groups`        |
| **Auth**    | Required                         |

**Request Body**

| Field        | Type     | Required | Description                                                                  |
|:-------------|:---------|:--------:|:-----------------------------------------------------------------------------|
| `name`       | `string` | Yes      | Group name (max 50 chars)                                                    |
| `icon`       | `string` | No       | Material icon name                                                           |
| `color`      | `string` | No       | Hex color code                                                               |
| `budgetType` | `enum`   | No       | `WEEKLY`, `MONTHLY` (default), `NONE`                                        |
| `visibility` | `string` | No       | `SHARED` (default) or `PRIVATE`. Private groups are only visible to the creator. |

**Response `201 Created`**: `ApiResponse<CategoryGroupResponse>`

---

### 3. Update Category Group

| Item        | Value                                |
|:------------|:-------------------------------------|
| **Method**  | `PUT`                                |
| **Path**    | `/api/v1/category-groups/{id}`       |
| **Auth**    | Required                             |

**Request Body** (all fields optional)

| Field          | Type      | Description                                          |
|:---------------|:----------|:-----------------------------------------------------|
| `name`         | `string`  | Group name (max 50 chars)                            |
| `icon`         | `string`  | Material icon name                                   |
| `color`        | `string`  | Hex color code                                       |
| `budgetType`   | `enum`    | `WEEKLY`, `MONTHLY`, or `NONE`                       |
| `displayOrder` | `integer` | Sort order                                           |
| `visibility`   | `string`  | `SHARED` or `PRIVATE`. Only the owner can change this field. |

**Response `200 OK`**: `ApiResponse<CategoryGroupResponse>`

---

### 4. Delete Category Group

Deletes a category group (including default groups). Categories in the group become uncategorized (`group_id` set to null).

| Item        | Value                                |
|:------------|:-------------------------------------|
| **Method**  | `DELETE`                             |
| **Path**    | `/api/v1/category-groups/{id}`       |
| **Auth**    | Required                             |

**Response `204 No Content`**

| Status | Error Code        | Description                          |
|:-------|:------------------|:-------------------------------------|
| `403`  | `FORBIDDEN`       | Group belongs to a different couple  |
| `404`  | `GROUP_NOT_FOUND` | Category group does not exist        |

---

### 5. Reorder Category Groups

Updates the display order of all category groups for the couple in a single call. All group IDs owned by the couple must be provided; the server rejects partial lists.

| Item        | Value                                     |
|:------------|:------------------------------------------|
| **Method**  | `PUT`                                     |
| **Path**    | `/api/v1/category-groups/reorder`         |
| **Auth**    | Required                                  |

**Request Body**

```json
{
  "orderedIds": [
    "550e8400-e29b-41d4-a716-446655440010",
    "550e8400-e29b-41d4-a716-446655440011",
    "550e8400-e29b-41d4-a716-446655440012"
  ]
}
```

| Field        | Type          | Required | Description                                                           |
|:-------------|:--------------|:--------:|:----------------------------------------------------------------------|
| `orderedIds` | `List<UUID>`  | Yes      | Ordered list of all category group IDs. Position in list = new `displayOrder`. |

**Response `200 OK`**: `ApiResponse<void>` (`data` is `null`)

```json
{
  "success": true,
  "data": null,
  "timestamp": "2026-03-19T12:00:00Z"
}
```

**Error Responses**

| Status | Error Code         | Description                                                        |
|:-------|:-------------------|:-------------------------------------------------------------------|
| `400`  | `VALIDATION_ERROR` | `orderedIds` is empty or null                                      |
| `404`  | `GROUP_NOT_FOUND`  | One or more IDs do not belong to the caller's couple               |

---

## Payment Methods

Base path: `/api/v1/payment-methods`

All endpoints require the `Authorization: Bearer {accessToken}` header.
The caller must be in an active couple.

---

### 1. List Payment Methods

Retrieves all payment methods for the couple.

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `GET`                            |
| **Path**    | `/api/v1/payment-methods`        |
| **Auth**    | Required                         |

**Response `200 OK`**: `ApiResponse<List<PaymentMethodResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440030",
      "name": "현금",
      "type": "CASH",
      "settlementDay": null,
      "closingDay": null,
      "isActive": true,
      "isDefault": true,
      "displayOrder": 0,
      "balance": 150000,
      "linkedBankId": null,
      "linkedBankName": null,
      "createdAt": "2024-01-01T12:00:00Z"
    },
    {
      "id": "550e8400-e29b-41d4-a716-446655440031",
      "name": "신한카드",
      "type": "CREDIT",
      "settlementDay": 15,
      "closingDay": 25,
      "isActive": true,
      "isDefault": false,
      "displayOrder": 2,
      "balance": null,
      "linkedBankId": "550e8400-e29b-41d4-a716-446655440032",
      "linkedBankName": "신한은행",
      "createdAt": "2024-01-01T12:00:00Z"
    }
  ]
}
```

---

### 2. Create Payment Method

| Item        | Value                            |
|:------------|:---------------------------------|
| **Method**  | `POST`                           |
| **Path**    | `/api/v1/payment-methods`        |
| **Auth**    | Required                         |

**Request Body**

| Field           | Type      | Required | Description                                                                                          |
|:----------------|:----------|:--------:|:-----------------------------------------------------------------------------------------------------|
| `name`          | `string`  | Yes      | Payment method name (max 100 chars)                                                                  |
| `type`          | `enum`    | Yes      | `CASH`, `DEBIT`, `CREDIT`, or `BANK`                                                                 |
| `settlementDay` | `integer` | No       | Card settlement day (1-31, for CREDIT)                                                               |
| `closingDay`    | `integer` | No       | Card closing day (1-31, for CREDIT)                                                                  |
| `linkedBankId`  | `UUID`    | No       | ID of a BANK-type payment method in the same couple to link as the settlement bank (CREDIT type only) |

**Response `201 Created`**: `ApiResponse<PaymentMethodResponse>`

---

### 3. Update Payment Method

| Item        | Value                                |
|:------------|:-------------------------------------|
| **Method**  | `PUT`                                |
| **Path**    | `/api/v1/payment-methods/{id}`       |
| **Auth**    | Required                             |

**Request Body** (all fields optional)

| Field           | Type      | Description                                                                                          |
|:----------------|:----------|:-----------------------------------------------------------------------------------------------------|
| `name`          | `string`  | Payment method name                                                                                  |
| `settlementDay` | `integer` | Card settlement day (1-31)                                                                           |
| `closingDay`    | `integer` | Card closing day (1-31)                                                                              |
| `isActive`      | `boolean` | Active status                                                                                        |
| `displayOrder`  | `integer` | Sort order                                                                                           |
| `linkedBankId`  | `UUID` \| `null` | Set to a BANK-type payment method UUID to link it; pass `null` (PatchValue) to unlink (CREDIT only) |

**Response `200 OK`**: `ApiResponse<PaymentMethodResponse>`

---

### 4. Delete Payment Method

Default payment methods cannot be deleted.

| Item        | Value                                |
|:------------|:-------------------------------------|
| **Method**  | `DELETE`                             |
| **Path**    | `/api/v1/payment-methods/{id}`       |
| **Auth**    | Required                             |

**Response `204 No Content`**

---

### 5. Card Pending Summary

Returns unsettled credit card amounts for a given month.

| Item        | Value                                              |
|:------------|:---------------------------------------------------|
| **Method**  | `GET`                                              |
| **Path**    | `/api/v1/payment-methods/card-pending`             |
| **Auth**    | Required                                           |

**Query Parameters**

| Parameter | Type      | Required | Description          |
|:----------|:----------|:--------:|:---------------------|
| `year`    | `integer` | Yes      | Year (e.g. 2026)     |
| `month`   | `integer` | Yes      | Month (1-12)         |

**Response `200 OK`**: `ApiResponse<List<CardPendingResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "paymentMethod": {
        "id": "550e8400-e29b-41d4-a716-446655440031",
        "name": "신한카드",
        "type": "CREDIT",
        "settlementDay": 15,
        "closingDay": 25,
        "isActive": true,
        "isDefault": false,
        "displayOrder": 2,
        "createdAt": "2024-01-01T12:00:00Z"
      },
      "pendingAmount": 450000,
      "settlementDate": "2026-04-15",
      "transactionCount": 12
    }
  ]
}
```

---

### 6. Card Settlement Summary

Returns credit card spending grouped by settlement month for the previous and current calendar months. Used to display how much is due for settlement per card.

> **Note**: CREDIT↔CREDIT transfers (card-to-card) are prohibited. A transfer where both the source and destination payment methods have type `CREDIT` will be rejected with `400 VALIDATION_ERROR`.

| Item        | Value                                                          |
|:------------|:---------------------------------------------------------------|
| **Method**  | `GET`                                                          |
| **Path**    | `/api/v1/payment-methods/card-settlement-summary`             |
| **Auth**    | Required                                                       |

**Response `200 OK`**: `ApiResponse<CardSettlementSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "previousMonth": {
      "year": 2026,
      "month": 2,
      "totalAmount": 350000,
      "cards": [
        {
          "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
          "paymentMethodName": "롯데카드",
          "amount": 200000,
          "settlementDate": "2026-02-25",
          "transactionCount": 15
        },
        {
          "paymentMethodId": "550e8400-e29b-41d4-a716-446655440035",
          "paymentMethodName": "신한카드",
          "amount": 150000,
          "settlementDate": "2026-02-15",
          "transactionCount": 8
        }
      ]
    },
    "currentMonth": {
      "year": 2026,
      "month": 3,
      "totalAmount": 420000,
      "cards": [
        {
          "paymentMethodId": "550e8400-e29b-41d4-a716-446655440031",
          "paymentMethodName": "롯데카드",
          "amount": 420000,
          "settlementDate": "2026-03-25",
          "transactionCount": 22
        }
      ]
    }
  }
}
```

---

## Weekly Budgets

Extends the existing Budget endpoints with weekly tracking capabilities.

---

### 1. Weekly Overview

Returns weekly spending snapshots for a given month.

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/api/v1/budgets/weekly`                 |
| **Auth**    | Required                                 |

**Query Parameters**

| Parameter | Type      | Required | Description       |
|:----------|:----------|:--------:|:------------------|
| `year`    | `integer` | Yes      | Year (e.g. 2026)  |
| `month`   | `integer` | Yes      | Month (1-12)      |

**Response `200 OK`**: `ApiResponse<WeeklyOverviewResponse>`

```json
{
  "success": true,
  "data": {
    "yearMonth": "2026-03",
    "weeks": [
      {
        "weekNumber": 1,
        "weekStart": "2026-03-01",
        "weekEnd": "2026-03-07",
        "budgetAmount": 200000,
        "spentAmount": 180000,
        "remainingAmount": 20000,
        "usageRate": 90.0,
        "status": "UNDER"
      }
    ]
  }
}
```

---

### 2. Current Week Summary

Returns this week's budget vs spending grouped by WEEKLY category groups.

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/api/v1/budgets/weekly/current`         |
| **Auth**    | Required                                 |

**Response `200 OK`**: `ApiResponse<CurrentWeekSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "yearMonth": "2026-03",
    "weekNumber": 2,
    "weekStart": "2026-03-08",
    "weekEnd": "2026-03-14",
    "groups": [
      {
        "groupId": "550e8400-e29b-41d4-a716-446655440010",
        "groupName": "생활비",
        "budgetAmount": 200000,
        "spentAmount": 120000,
        "remainingAmount": 80000,
        "usageRate": 60.0
      }
    ]
  }
}
```

---

## Reports

Base path: `/api/v1/reports`

Rule-based spending analysis reports. No AI — pure aggregation and pattern detection.

---

### 1. Weekly Report

Detailed weekly spending analysis with overspend detection and daily patterns.

| Item        | Value                                              |
|:------------|:---------------------------------------------------|
| **Method**  | `GET`                                              |
| **Path**    | `/api/v1/reports/weekly`                           |
| **Auth**    | Required                                           |

**Query Parameters**

| Parameter | Type      | Required | Description        |
|:----------|:----------|:--------:|:-------------------|
| `year`    | `integer` | Yes      | Year (e.g. 2026)   |
| `month`   | `integer` | Yes      | Month (1-12)       |
| `week`    | `integer` | Yes      | Week number (1-5)  |

**Response `200 OK`**: `ApiResponse<WeeklyReportResponse>`

---

### 2. Monthly Report

Monthly spending overview with group summaries, month-over-month comparison, and day-of-week patterns.

| Item        | Value                                              |
|:------------|:---------------------------------------------------|
| **Method**  | `GET`                                              |
| **Path**    | `/api/v1/reports/monthly`                          |
| **Auth**    | Required                                           |

**Query Parameters**

| Parameter | Type      | Required | Description       |
|:----------|:----------|:--------:|:------------------|
| `year`    | `integer` | Yes      | Year (e.g. 2026)  |
| `month`   | `integer` | Yes      | Month (1-12)      |

**Response `200 OK`**: `ApiResponse<MonthlyReportResponse>`

---

## Recurring Transactions

Base path: `/api/v1/recurring-transactions`

All endpoints require the `Authorization: Bearer {accessToken}` header.

---

### 1. List Recurring Transactions

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `GET`                                    |
| **Path**    | `/api/v1/recurring-transactions`         |
| **Auth**    | Required                                 |

**Response `200 OK`**: `ApiResponse<List<RecurringTransactionResponse>>`

---

### 2. Create Recurring Transaction

| Item        | Value                                    |
|:------------|:-----------------------------------------|
| **Method**  | `POST`                                   |
| **Path**    | `/api/v1/recurring-transactions`         |
| **Auth**    | Required                                 |

**Request Body**

| Field             | Type      | Required | Description                                                         |
|:------------------|:----------|:--------:|:--------------------------------------------------------------------|
| `type`            | `enum`    | Yes      | `INCOME` or `EXPENSE`                                               |
| `amount`          | `long`    | Yes      | Amount (> 0)                                                        |
| `description`     | `string`  | Yes      | Short description                                                   |
| `memo`            | `string`  | No       | Optional note                                                       |
| `categoryId`      | `UUID`    | No       | Category ID                                                         |
| `paymentMethodId` | `UUID`    | No       | Payment method ID                                                   |
| `frequency`       | `enum`    | Yes      | `DAILY`, `WEEKLY`, `MONTHLY`, or `YEARLY`                           |
| `dayOfMonth`      | `integer` | No       | Day of month (1-31, required for MONTHLY)                           |
| `dayOfWeek`       | `integer` | No       | Day of week (1=MON..7=SUN, required for WEEKLY)                     |
| `visibility`      | `string`  | No       | `SHARED` (default) or `PRIVATE`. The `author_id` column serves as the owner for private recurring transactions. |

**Response `201 Created`**: `ApiResponse<RecurringTransactionResponse>`

---

### 3. Update Recurring Transaction

| Item        | Value                                        |
|:------------|:---------------------------------------------|
| **Method**  | `PUT`                                        |
| **Path**    | `/api/v1/recurring-transactions/{id}`        |
| **Auth**    | Required                                     |

**Request Body** (all optional)

| Field             | Type      | Description                                                  |
|:------------------|:----------|:-------------------------------------------------------------|
| `amount`          | `long`    | Amount (> 0)                                                 |
| `description`     | `string`  | Description                                                  |
| `memo`            | `string`  | Note                                                         |
| `categoryId`      | `UUID`    | Category ID                                                  |
| `paymentMethodId` | `UUID`    | Payment method ID                                            |
| `dayOfMonth`      | `integer` | Day of month                                                 |
| `dayOfWeek`       | `integer` | Day of week                                                  |
| `isActive`        | `boolean` | Active/inactive                                              |
| `visibility`      | `string`  | `SHARED` or `PRIVATE`. Only the author can change this field.|

**Response `200 OK`**: `ApiResponse<RecurringTransactionResponse>`

---

### 4. Delete Recurring Transaction

| Item        | Value                                        |
|:------------|:---------------------------------------------|
| **Method**  | `DELETE`                                     |
| **Path**    | `/api/v1/recurring-transactions/{id}`        |
| **Auth**    | Required                                     |

**Response `204 No Content`**

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

### InvitationStatusResponse

| Field       | Type     | Nullable | Description                                             |
|:------------|:---------|:--------:|:--------------------------------------------------------|
| `code`      | `string` | No       | 8-character alphanumeric invitation code                |
| `expiresAt` | `string` | No       | ISO 8601 expiry timestamp                               |
| `status`    | `string` | No       | `PENDING` \| `EXPIRED` \| `ACCEPTED`                   |

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

| Field          | Type      | Nullable | Description                                                 |
|:---------------|:----------|:--------:|:------------------------------------------------------------|
| `id`           | `UUID`    | No       | Category unique identifier                                  |
| `name`         | `string`  | No       | Category name                                               |
| `type`         | `enum`    | No       | `INCOME` or `EXPENSE`                                       |
| `icon`         | `string`  | Yes      | Material icon name                                          |
| `color`        | `string`  | Yes      | Hex color code (e.g., `#FF5733`)                            |
| `isDefault`    | `boolean` | No       | Whether this is a system default                            |
| `displayOrder` | `integer` | No       | Sort order within type group                                |
| `groupId`      | `UUID`    | Yes      | Category group ID (null if ungrouped)                       |
| `visibility`   | `string`  | No       | `SHARED` or `PRIVATE`                                       |
| `ownerId`      | `UUID`    | Yes      | Owner user ID. Present only when `visibility` is `PRIVATE`. |
| `createdAt`    | `string`  | No       | ISO 8601 timestamp                                          |

### CategoryGroupResponse

| Field          | Type                    | Nullable | Description                                                 |
|:---------------|:------------------------|:--------:|:------------------------------------------------------------|
| `id`           | `UUID`                  | No       | Category group unique identifier                            |
| `name`         | `string`                | No       | Group name                                                  |
| `icon`         | `string`                | Yes      | Material icon name                                          |
| `color`        | `string`                | Yes      | Hex color code                                              |
| `budgetType`   | `enum`                  | No       | `WEEKLY`, `MONTHLY`, or `NONE`                              |
| `displayOrder` | `integer`               | No       | Sort order                                                  |
| `isDefault`    | `boolean`               | No       | Whether this is a system default                            |
| `categories`   | `List<CategoryResponse>`| No       | Nested categories in this group                             |
| `visibility`   | `string`                | No       | `SHARED` or `PRIVATE`                                       |
| `ownerId`      | `UUID`                  | Yes      | Owner user ID. Present only when `visibility` is `PRIVATE`. |
| `createdAt`    | `string`                | No       | ISO 8601 timestamp                                          |

### PaymentMethodResponse

| Field            | Type      | Nullable | Description                                                                               |
|:-----------------|:----------|:--------:|:------------------------------------------------------------------------------------------|
| `id`             | `UUID`    | No       | Payment method unique identifier                                                          |
| `name`           | `string`  | No       | Payment method name                                                                       |
| `type`           | `enum`    | No       | `CASH`, `DEBIT`, `CREDIT`, or `BANK`                                                      |
| `settlementDay`  | `integer` | Yes      | Card settlement day (1-31)                                                                |
| `closingDay`     | `integer` | Yes      | Card closing day (1-31)                                                                   |
| `isActive`       | `boolean` | No       | Whether this method is active                                                             |
| `isDefault`      | `boolean` | No       | Whether this is a system default                                                          |
| `displayOrder`   | `integer` | No       | Sort order                                                                                |
| `balance`        | `long`    | Yes      | Computed balance (null for `CREDIT` type). `BANK`/`CASH`/`DEBIT`: income transfers − expense transfers |
| `linkedBankId`   | `UUID`    | Yes      | ID of the linked BANK-type payment method (only for `CREDIT` type)                       |
| `linkedBankName` | `string`  | Yes      | Display name of the linked bank (only for `CREDIT` type)                                 |
| `createdAt`      | `string`  | No       | ISO 8601 timestamp                                                                        |

### CardPendingResponse

| Field              | Type                    | Nullable | Description                        |
|:-------------------|:------------------------|:--------:|:-----------------------------------|
| `paymentMethod`    | `PaymentMethodResponse` | No       | The credit card                    |
| `pendingAmount`    | `long`                  | No       | Total unsettled amount             |
| `settlementDate`   | `string`                | Yes      | Next settlement date (YYYY-MM-DD) |
| `transactionCount` | `integer`               | No       | Number of pending transactions     |

### CategorySummary

| Field   | Type     | Nullable | Description         |
|:--------|:---------|:--------:|:--------------------|
| `id`    | `UUID`   | No       | Category ID         |
| `name`  | `string` | No       | Category name       |
| `type`  | `enum`   | No       | `INCOME` or `EXPENSE` |
| `icon`  | `string` | Yes      | Material icon name  |
| `color` | `string` | Yes      | Hex color code      |

### TransactionResponse

| Field               | Type              | Nullable | Description                                                 |
|:--------------------|:------------------|:--------:|:------------------------------------------------------------|
| `id`                | `UUID`            | No       | Transaction unique identifier                               |
| `coupleId`          | `UUID`            | No       | Owning couple ID                                            |
| `author`            | `UserSummary`     | No       | User who recorded the transaction                           |
| `category`          | `CategorySummary` | Yes      | Category (null if uncategorized)                            |
| `type`              | `enum`            | No       | `INCOME` or `EXPENSE`                                       |
| `amount`            | `long`            | No       | Amount in KRW (always > 0)                                  |
| `description`       | `string`          | No       | Short description                                           |
| `memo`              | `string`          | Yes      | Optional longer note                                        |
| `transactionDate`   | `string`          | No       | ISO 8601 date: `YYYY-MM-DD`                                 |
| `paymentMethodId`   | `UUID`            | Yes      | Payment method used                                         |
| `paymentMethodName` | `string`          | Yes      | Payment method display name                                 |
| `paymentMethodType` | `enum`            | Yes      | `CASH`, `DEBIT`, or `CREDIT`                                |
| `settlementDate`    | `string`          | Yes      | Credit card settlement date                                 |
| `visibility`        | `string`          | No       | `SHARED` or `PRIVATE`                                       |
| `ownerId`           | `UUID`            | Yes      | Owner user ID. Present only when `visibility` is `PRIVATE`. |
| `createdAt`         | `string`          | No       | ISO 8601 timestamp                                          |
| `updatedAt`         | `string`          | No       | ISO 8601 timestamp                                          |

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

### BudgetResponse

| Field          | Type              | Nullable | Description                                                                           |
|:---------------|:------------------|:--------:|:--------------------------------------------------------------------------------------|
| `id`           | `UUID`            | No       | Budget unique identifier                                                              |
| `coupleId`     | `UUID`            | No       | Owning couple ID                                                                      |
| `category`     | `CategorySummary` | Yes      | Category (null when budget targets a group or is a total budget with no category)     |
| `groupId`      | `UUID`            | Yes      | Category group ID (null when budget targets a category or is a total budget)          |
| `groupName`    | `string`          | Yes      | Category group name (null when `groupId` is null)                                     |
| `yearMonth`    | `string`          | No       | Target month in `YYYY-MM` format                                                      |
| `amount`       | `long`            | No       | Budget amount in KRW (always > 0)                                                     |
| `budgetPeriod` | `string`          | No       | Budget period type: `MONTHLY` or `WEEKLY`                                             |
| `weeklyAmount` | `long`            | Yes      | Per-week amount (omitted unless `budgetPeriod` is `WEEKLY`)                           |
| `visibility`   | `string`          | No       | `SHARED` or `PRIVATE`                                                                 |
| `ownerId`      | `UUID`            | Yes      | Owner user ID. Present only when `visibility` is `PRIVATE`.                           |
| `createdAt`    | `string`          | No       | ISO 8601 timestamp                                                                    |
| `updatedAt`    | `string`          | No       | ISO 8601 timestamp                                                                    |

### BudgetSummaryResponse

| Field        | Type                          | Description                            |
|:-------------|:------------------------------|:---------------------------------------|
| `yearMonth`  | `string`                      | Target month in `YYYY-MM` format       |
| `totalBudget`| `long`                        | Sum of all budget amounts for the month |
| `totalSpent` | `long`                        | Sum of all expense transactions for the month |
| `items`      | `List<BudgetSummaryItemResponse>` | Per-budget breakdown               |

### BudgetSummaryItemResponse

| Field             | Type              | Nullable | Description                                      |
|:------------------|:------------------|:--------:|:-------------------------------------------------|
| `category`        | `CategorySummary` | Yes      | Category (null = total monthly budget entry)     |
| `budgetAmount`    | `long`            | No       | Planned budget amount                            |
| `spentAmount`     | `long`            | No       | Actual spent amount for the category/month       |
| `remainingAmount` | `long`            | No       | `budgetAmount - spentAmount` (can be negative)   |
| `usageRate`       | `double`          | No       | `(spentAmount / budgetAmount) * 100` (0–100+)    |

### StatisticsSummaryResponse

| Field              | Type      | Description                                  |
|:-------------------|:----------|:---------------------------------------------|
| `yearMonth`        | `string`  | Target month in `YYYY-MM` format             |
| `totalIncome`      | `long`    | Sum of all income transactions               |
| `totalExpense`     | `long`    | Sum of all expense transactions              |
| `balance`          | `long`    | `totalIncome - totalExpense`                 |
| `transactionCount` | `integer` | Total number of transactions in the month    |

### CategoryStatisticsResponse

| Field              | Type              | Description                                         |
|:-------------------|:------------------|:----------------------------------------------------|
| `category`         | `CategorySummary` | The category                                        |
| `amount`           | `long`            | Total amount for this category in the month         |
| `percentage`       | `double`          | Percentage of total income/expense (0–100)          |
| `transactionCount` | `integer`         | Number of transactions in this category             |

### MonthlyTrendResponse

| Field          | Type     | Description                          |
|:---------------|:---------|:-------------------------------------|
| `yearMonth`    | `string` | Month in `YYYY-MM` format            |
| `totalIncome`  | `long`   | Sum of all income transactions       |
| `totalExpense` | `long`   | Sum of all expense transactions      |
| `balance`      | `long`   | `totalIncome - totalExpense`         |

### PocketResponse

| Field             | Type      | Nullable | Description                                                                   |
|:------------------|:----------|:--------:|:------------------------------------------------------------------------------|
| `id`              | `UUID`    | No       | Pocket unique identifier                                                      |
| `name`            | `string`  | No       | Pocket display name                                                           |
| `type`            | `enum`    | No       | `LIVING`, `FIXED`, `CARD_PENDING`, `SAVINGS`, `CUSTOM`                       |
| `allocatedAmount` | `long`    | No       | Allocated budget in KRW                                                       |
| `balance`         | `long`    | No       | Computed balance: `allocatedAmount + transferIn - transferOut - expense`      |
| `icon`            | `string`  | Yes      | Material icon name                                                            |
| `color`           | `string`  | Yes      | Hex color code (e.g. `#FF5733`)                                               |
| `displayOrder`    | `integer` | No       | Sort order                                                                    |
| `isActive`        | `boolean` | No       | Whether this pocket is active                                                 |
| `visibility`      | `string`  | No       | `SHARED` or `PRIVATE`                                                         |
| `ownerId`         | `UUID`    | Yes      | Owner user ID. Present only when `visibility` is `PRIVATE`.                   |

### PocketSummaryResponse

| Field              | Type              | Nullable | Description                                   |
|:-------------------|:------------------|:--------:|:----------------------------------------------|
| `pocket`           | `PocketResponse`  | No       | The pocket detail                             |
| `totalIncome`      | `long`            | No       | Sum of INCOME transactions linked to pocket   |
| `totalExpense`     | `long`            | No       | Sum of EXPENSE transactions linked to pocket  |
| `totalTransferIn`  | `long`            | No       | Sum of incoming pocket transfers              |
| `totalTransferOut` | `long`            | No       | Sum of outgoing pocket transfers              |
| `balance`          | `long`            | No       | `allocatedAmount + transferIn - transferOut - expense` |

### PocketSummary

Abbreviated pocket reference used within transfer responses.

| Field  | Type     | Nullable | Description          |
|:-------|:---------|:--------:|:---------------------|
| `id`   | `UUID`   | No       | Pocket unique identifier |
| `name` | `string` | No       | Pocket display name  |

### PocketTransferResponse

| Field          | Type            | Nullable | Description                            |
|:---------------|:----------------|:--------:|:---------------------------------------|
| `id`           | `UUID`          | No       | Transfer unique identifier             |
| `fromPocket`   | `PocketSummary` | No       | Source pocket (id and name)            |
| `toPocket`     | `PocketSummary` | No       | Destination pocket (id and name)       |
| `amount`       | `long`          | No       | Transfer amount in KRW (always > 0)    |
| `description`  | `string`        | Yes      | Optional transfer note                 |
| `transferDate` | `string`        | No       | ISO 8601 date: `YYYY-MM-DD`            |
| `authorId`     | `UUID`          | No       | ID of user who created the transfer    |

### TransferResponse

| Field                        | Type                      | Nullable | Description                                                              |
|:-----------------------------|:--------------------------|:--------:|:-------------------------------------------------------------------------|
| `id`                         | `UUID`                    | No       | Transfer unique identifier                                               |
| `coupleId`                   | `UUID`                    | No       | Owning couple ID                                                         |
| `author`                     | `UserSummary`             | No       | User who created the transfer                                            |
| `sourcePaymentMethod`        | `PaymentMethodSummary`    | No       | Source payment method (id, name, type)                                   |
| `destinationPaymentMethod`   | `PaymentMethodSummary`    | No       | Destination payment method (id, name, type)                              |
| `amount`                     | `long`                    | No       | Transfer amount in KRW (always > 0)                                      |
| `description`                | `string`                  | Yes      | Short label for the transfer (max 255)                                   |
| `memo`                       | `string`                  | Yes      | Optional additional notes                                                |
| `transferDate`               | `string`                  | No       | ISO 8601 date: `YYYY-MM-DD`                                              |
| `autoSettlementKey`          | `string`                  | Yes      | Deduplication key for system-generated auto-settlement transfers (null for manual transfers) |
| `createdAt`                  | `string`                  | No       | ISO 8601 timestamp                                                       |

### PaymentMethodSummary

Abbreviated payment method reference used within transfer responses.

| Field  | Type     | Nullable | Description                          |
|:-------|:---------|:--------:|:-------------------------------------|
| `id`   | `UUID`   | No       | Payment method unique identifier     |
| `name` | `string` | No       | Payment method display name          |
| `type` | `enum`   | No       | `CASH`, `DEBIT`, `CREDIT`, or `BANK` |

### CardSettlementSummaryResponse

| Field           | Type                         | Nullable | Description                               |
|:----------------|:-----------------------------|:--------:|:------------------------------------------|
| `previousMonth` | `CardSettlementMonthSummary` | No       | Settlement data for the previous calendar month |
| `currentMonth`  | `CardSettlementMonthSummary` | No       | Settlement data for the current calendar month  |

### CardSettlementMonthSummary

| Field         | Type                          | Nullable | Description                              |
|:--------------|:------------------------------|:--------:|:-----------------------------------------|
| `year`        | `integer`                     | No       | Year (e.g., 2026)                        |
| `month`       | `integer`                     | No       | Month 1–12                               |
| `totalAmount` | `long`                        | No       | Sum of all card spending amounts         |
| `cards`       | `List<CardSettlementCardItem>`| No       | Per-card breakdown                       |

### CardSettlementCardItem

| Field               | Type      | Nullable | Description                                   |
|:--------------------|:----------|:--------:|:----------------------------------------------|
| `paymentMethodId`   | `UUID`    | No       | Credit card payment method ID                 |
| `paymentMethodName` | `string`  | No       | Credit card display name                      |
| `amount`            | `long`    | No       | Total spending amount for this card            |
| `settlementDate`    | `string`  | Yes      | Next settlement date `YYYY-MM-DD` (null if no `settlementDay` configured) |
| `transactionCount`  | `integer` | No       | Number of transactions for this card          |

### RecurringTransactionResponse

| Field             | Type              | Nullable | Description                                                         |
|:------------------|:------------------|:--------:|:--------------------------------------------------------------------|
| `id`              | `UUID`            | No       | Recurring transaction unique identifier                             |
| `coupleId`        | `UUID`            | No       | Owning couple ID                                                    |
| `author`          | `UserSummary`     | No       | User who created the recurring entry                                |
| `category`        | `CategorySummary` | Yes      | Category (null if uncategorized)                                    |
| `type`            | `enum`            | No       | `INCOME` or `EXPENSE`                                               |
| `amount`          | `long`            | No       | Amount in KRW (always > 0)                                          |
| `description`     | `string`          | No       | Short description                                                   |
| `memo`            | `string`          | Yes      | Optional note                                                       |
| `paymentMethodId` | `UUID`            | Yes      | Payment method ID                                                   |
| `frequency`       | `enum`            | No       | `DAILY`, `WEEKLY`, `MONTHLY`, or `YEARLY`                           |
| `dayOfMonth`      | `integer`         | Yes      | Day of month (applicable for `MONTHLY` frequency)                   |
| `dayOfWeek`       | `integer`         | Yes      | Day of week (applicable for `WEEKLY` frequency)                     |
| `isActive`        | `boolean`         | No       | Whether the rule is currently active                                |
| `visibility`      | `string`          | No       | `SHARED` or `PRIVATE`                                               |
| `createdAt`       | `string`          | No       | ISO 8601 timestamp                                                  |
| `updatedAt`       | `string`          | No       | ISO 8601 timestamp                                                  |

### DistributeResponse

| Field                         | Type     | Nullable | Description                                    |
|:------------------------------|:---------|:--------:|:-----------------------------------------------|
| `distributions`               | `array`  | No       | List of pocket allocation entries              |
| `distributions[].pocketId`   | `UUID`   | No       | Pocket unique identifier                       |
| `distributions[].pocketName` | `string` | No       | Pocket display name                            |
| `distributions[].amount`     | `long`   | No       | Amount allocated to this pocket                |
| `totalDistributed`            | `long`   | No       | Sum of all distribution amounts                |

---

## Money Pockets

Base path: `/api/v1/pockets`

All endpoints require the `Authorization: Bearer {accessToken}` header.

Money Pockets represent named budget envelopes for a couple (e.g., living expenses, fixed costs, savings). Each pocket tracks allocated amounts and actual spending via linked transactions and transfers.

**Pocket types**: `LIVING` (생활비), `FIXED` (고정지출), `CARD_PENDING` (카드미결제), `SAVINGS` (저축), `CUSTOM` (직접입력)

**Balance formula**: `allocatedAmount + totalTransferIn - totalTransferOut - totalExpense`
where `totalExpense` is the sum of `EXPENSE` transactions linked to this pocket via `pocket_id`.

---

### 1. List Pockets

Returns all active pockets for the authenticated couple with balance summary.

| Item        | Value                     |
|:------------|:--------------------------|
| **Method**  | `GET`                     |
| **Path**    | `/api/v1/pockets`         |
| **Auth**    | Required                  |

**Response `200 OK`**: `ApiResponse<List<PocketResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440100",
      "name": "생활비",
      "type": "LIVING",
      "allocatedAmount": 1000000,
      "balance": 750000,
      "icon": "home",
      "color": "#4CAF50",
      "displayOrder": 0,
      "isActive": true
    }
  ],
  "timestamp": "2026-03-12T10:00:00Z"
}
```

---

### 2. Create Pocket

| Item        | Value                     |
|:------------|:--------------------------|
| **Method**  | `POST`                    |
| **Path**    | `/api/v1/pockets`         |
| **Auth**    | Required                  |

**Request Body**

| Field             | Type      | Required | Description                                                                   |
|:------------------|:----------|:--------:|:------------------------------------------------------------------------------|
| `name`            | `string`  | Yes      | Pocket display name (max 50 chars)                                            |
| `type`            | `enum`    | Yes      | `LIVING`, `FIXED`, `CARD_PENDING`, `SAVINGS`, `CUSTOM`                       |
| `allocatedAmount` | `long`    | Yes      | Allocated budget amount in KRW (>= 0)                                         |
| `icon`            | `string`  | No       | Material icon name                                                            |
| `color`           | `string`  | No       | Hex color code (e.g. `#FF5733`)                                               |
| `visibility`      | `string`  | No       | `SHARED` (default) or `PRIVATE`. Private pockets are only visible to the creator. |

**Response `201 Created`**: `ApiResponse<PocketResponse>`

**Error Responses**

| Status | Error Code          | Description                    |
|:------:|:--------------------|:-------------------------------|
| `400`  | `VALIDATION_ERROR`  | Missing required fields         |
| `404`  | `COUPLE_NOT_FOUND`  | User is not in an active couple |

---

### 3. Update Pocket

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `PUT`                         |
| **Path**    | `/api/v1/pockets/{id}`        |
| **Auth**    | Required                      |

**Request Body** (all fields optional)

| Field             | Type      | Description                                                      |
|:------------------|:----------|:-----------------------------------------------------------------|
| `name`            | `string`  | Pocket display name (max 50 chars)                               |
| `type`            | `enum`    | `LIVING`, `FIXED`, `CARD_PENDING`, `SAVINGS`, `CUSTOM`          |
| `allocatedAmount` | `long`    | Allocated budget amount in KRW (>= 0)                            |
| `icon`            | `string`  | Material icon name                                               |
| `color`           | `string`  | Hex color code                                                   |
| `displayOrder`    | `integer` | Sort order                                                       |
| `visibility`      | `string`  | `SHARED` or `PRIVATE`. Only the owner can change this field.     |

**Response `200 OK`**: `ApiResponse<PocketResponse>`

**Error Responses**

| Status | Error Code          | Description                       |
|:------:|:--------------------|:----------------------------------|
| `404`  | `POCKET_NOT_FOUND`  | Requested pocket does not exist   |
| `403`  | `FORBIDDEN`         | Pocket belongs to another couple  |

---

### 4. Delete Pocket

Soft-deletes the pocket by setting `is_active = false`. The pocket's historical data is preserved.

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `DELETE`                      |
| **Path**    | `/api/v1/pockets/{id}`        |
| **Auth**    | Required                      |

**Response `204 No Content`**

**Error Responses**

| Status | Error Code          | Description                       |
|:------:|:--------------------|:----------------------------------|
| `404`  | `POCKET_NOT_FOUND`  | Requested pocket does not exist   |
| `403`  | `FORBIDDEN`         | Pocket belongs to another couple  |

---

### 5. Pocket Summary

Returns full balance breakdown for a single pocket.

| Item        | Value                             |
|:------------|:----------------------------------|
| **Method**  | `GET`                             |
| **Path**    | `/api/v1/pockets/{id}/summary`    |
| **Auth**    | Required                          |

**Response `200 OK`**: `ApiResponse<PocketSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "pocket": {
      "id": "550e8400-e29b-41d4-a716-446655440100",
      "name": "생활비",
      "type": "LIVING",
      "allocatedAmount": 1000000,
      "balance": 750000,
      "icon": "home",
      "color": "#4CAF50",
      "displayOrder": 0,
      "isActive": true
    },
    "totalIncome": 0,
    "totalExpense": 250000,
    "totalTransferIn": 0,
    "totalTransferOut": 0,
    "balance": 750000
  },
  "timestamp": "2026-03-12T10:00:00Z"
}
```

**Error Responses**

| Status | Error Code          | Description                       |
|:------:|:--------------------|:----------------------------------|
| `404`  | `POCKET_NOT_FOUND`  | Requested pocket does not exist   |

---

### 6. Distribute Income

Distributes a total income amount across multiple pockets by updating each pocket's `allocatedAmount`.

| Item        | Value                             |
|:------------|:----------------------------------|
| **Method**  | `POST`                            |
| **Path**    | `/api/v1/pockets/distribute`      |
| **Auth**    | Required                          |

**Request Body**

| Field                       | Type    | Required | Description                                 |
|:----------------------------|:--------|:--------:|:--------------------------------------------|
| `totalAmount`               | `long`  | Yes      | Total income amount to distribute (> 0)     |
| `distributions`             | `array` | Yes      | List of pocket allocation entries           |
| `distributions[].pocketId`  | `UUID`  | Yes      | Target pocket ID                            |
| `distributions[].amount`    | `long`  | Yes      | Amount to allocate to this pocket (> 0)     |

**Response `200 OK`**: `ApiResponse<DistributeResponse>`

```json
{
  "success": true,
  "data": {
    "distributions": [
      {
        "pocketId": "550e8400-e29b-41d4-a716-446655440100",
        "pocketName": "생활비",
        "amount": 600000
      },
      {
        "pocketId": "550e8400-e29b-41d4-a716-446655440101",
        "pocketName": "저축",
        "amount": 400000
      }
    ],
    "totalDistributed": 1000000
  },
  "timestamp": "2026-03-12T10:00:00Z"
}
```

**Error Responses**

| Status | Error Code          | Description                                              |
|:------:|:--------------------|:---------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`  | Missing required fields or amounts not positive          |
| `404`  | `POCKET_NOT_FOUND`  | One or more target pockets do not exist                  |

---

## Pocket Transfers

Base path: `/api/v1/pocket-transfers`

All endpoints require the `Authorization: Bearer {accessToken}` header.

Records money moved between pockets (e.g., surplus from living expenses moved to savings).

---

### 1. List Pocket Transfers

Returns pocket transfer history for the couple. Supports optional filtering.

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `GET`                         |
| **Path**    | `/api/v1/pocket-transfers`    |
| **Auth**    | Required                      |

**Query Parameters**

| Parameter      | Type     | Required | Description                              |
|:---------------|:---------|:--------:|:-----------------------------------------|
| `fromPocketId` | `UUID`   | No       | Filter by source pocket                  |
| `toPocketId`   | `UUID`   | No       | Filter by destination pocket             |
| `startDate`    | `string` | No       | Start date inclusive (`YYYY-MM-DD`)      |
| `endDate`      | `string` | No       | End date inclusive (`YYYY-MM-DD`)        |

**Response `200 OK`**: `ApiResponse<List<PocketTransferResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440200",
      "fromPocket": {
        "id": "550e8400-e29b-41d4-a716-446655440100",
        "name": "생활비"
      },
      "toPocket": {
        "id": "550e8400-e29b-41d4-a716-446655440101",
        "name": "저축"
      },
      "amount": 100000,
      "description": "이월 저축",
      "transferDate": "2026-03-12",
      "authorId": "550e8400-e29b-41d4-a716-446655440000"
    }
  ],
  "timestamp": "2026-03-12T10:00:00Z"
}
```

---

### 2. Create Pocket Transfer

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `POST`                        |
| **Path**    | `/api/v1/pocket-transfers`    |
| **Auth**    | Required                      |

**Request Body**

| Field          | Type     | Required | Description                            |
|:---------------|:---------|:--------:|:---------------------------------------|
| `fromPocketId` | `UUID`   | Yes      | Source pocket ID                       |
| `toPocketId`   | `UUID`   | Yes      | Destination pocket ID                  |
| `amount`       | `long`   | Yes      | Transfer amount in KRW (> 0)           |
| `description`  | `string` | No       | Optional transfer note (max 255 chars) |
| `transferDate` | `string` | Yes      | Transfer date (`YYYY-MM-DD`)           |

**Response `201 Created`**: `ApiResponse<PocketTransferResponse>`

**Error Responses**

| Status | Error Code          | Description                                            |
|:------:|:--------------------|:-------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`  | Missing required fields, amount <= 0, or same pocket   |
| `404`  | `POCKET_NOT_FOUND`  | Source or destination pocket does not exist            |
| `403`  | `FORBIDDEN`         | Pocket belongs to another couple                       |

---

## Transfers

Base path: `/api/v1/transfers`

All endpoints require the `Authorization: Bearer {accessToken}` header.

Records money moved between payment methods (e.g., bank account to cash withdrawal). Transfers are intentionally excluded from transaction statistics and budget calculations.

---

### 1. Create Transfer

| Item        | Value                    |
|:------------|:-------------------------|
| **Method**  | `POST`                   |
| **Path**    | `/api/v1/transfers`      |
| **Auth**    | Required                 |
| **Returns** | `201 Created`            |

**Request Body**

| Field                        | Type     | Required | Constraints              | Description                               |
|:-----------------------------|:---------|:--------:|:-------------------------|:------------------------------------------|
| `sourcePaymentMethodId`      | `UUID`   | Yes      | Must differ from dest    | Source payment method ID                  |
| `destinationPaymentMethodId` | `UUID`   | Yes      | Must differ from source  | Destination payment method ID             |
| `amount`                     | `long`   | Yes      | min=1, max=999999999     | Transfer amount in KRW                    |
| `description`                | `string` | No       | max=255                  | Short label for the transfer              |
| `transferDate`               | `string` | Yes      | `YYYY-MM-DD`             | Date of the transfer                      |
| `memo`                       | `string` | No       |                          | Optional additional notes                 |

**Request Example**

```json
{
  "sourcePaymentMethodId": "550e8400-e29b-41d4-a716-446655440010",
  "destinationPaymentMethodId": "550e8400-e29b-41d4-a716-446655440011",
  "amount": 100000,
  "description": "신한→현금 ATM 출금",
  "transferDate": "2026-03-25",
  "memo": null
}
```

**Response `201 Created`**: `ApiResponse<TransferResponse>`

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440200",
    "coupleId": "550e8400-e29b-41d4-a716-446655440001",
    "author": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "nickname": "홍길동"
    },
    "sourcePaymentMethod": {
      "id": "550e8400-e29b-41d4-a716-446655440010",
      "name": "신한은행",
      "type": "BANK"
    },
    "destinationPaymentMethod": {
      "id": "550e8400-e29b-41d4-a716-446655440011",
      "name": "현금",
      "type": "CASH"
    },
    "amount": 100000,
    "description": "신한→현금 ATM 출금",
    "memo": null,
    "transferDate": "2026-03-25",
    "autoSettlementKey": null,
    "createdAt": "2026-03-25T10:00:00"
  },
  "timestamp": "2026-03-25T10:00:00Z"
}
```

**Error Responses**

| Status | Error Code                    | Description                                              |
|:------:|:------------------------------|:---------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`            | Missing required fields, amount out of range, source == destination, or both source and destination are CREDIT type |
| `404`  | `PAYMENT_METHOD_NOT_FOUND`    | Source or destination payment method does not exist      |
| `403`  | `FORBIDDEN`                   | Payment method belongs to another couple                 |

---

### 2. List Transfers

Returns transfers for the couple filtered by month.

| Item        | Value                    |
|:------------|:-------------------------|
| **Method**  | `GET`                    |
| **Path**    | `/api/v1/transfers`      |
| **Auth**    | Required                 |

**Query Parameters**

| Parameter | Type      | Required | Description                             |
|:----------|:----------|:--------:|:----------------------------------------|
| `year`    | `integer` | Yes      | Year (e.g., `2026`)                     |
| `month`   | `integer` | Yes      | Month 1–12 (e.g., `3`)                  |

**Response `200 OK`**: `ApiResponse<List<TransferResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440200",
      "coupleId": "550e8400-e29b-41d4-a716-446655440001",
      "author": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "nickname": "홍길동"
      },
      "sourcePaymentMethod": {
        "id": "550e8400-e29b-41d4-a716-446655440010",
        "name": "신한은행",
        "type": "BANK"
      },
      "destinationPaymentMethod": {
        "id": "550e8400-e29b-41d4-a716-446655440011",
        "name": "현금",
        "type": "CASH"
      },
      "amount": 100000,
      "description": "신한→현금 ATM 출금",
      "memo": null,
      "transferDate": "2026-03-25",
      "autoSettlementKey": null,
      "createdAt": "2026-03-25T10:00:00"
    }
  ],
  "timestamp": "2026-03-25T10:00:00Z"
}
```

**Error Responses**

| Status | Error Code         | Description                        |
|:------:|:-------------------|:-----------------------------------|
| `400`  | `VALIDATION_ERROR` | Missing or invalid year/month      |

---

### 3. Get Transfer

| Item        | Value                       |
|:------------|:----------------------------|
| **Method**  | `GET`                       |
| **Path**    | `/api/v1/transfers/{id}`    |
| **Auth**    | Required                    |

**Path Parameters**

| Parameter | Type   | Description     |
|:----------|:-------|:----------------|
| `id`      | `UUID` | Transfer ID     |

**Response `200 OK`**: `ApiResponse<TransferResponse>`

**Error Responses**

| Status | Error Code          | Description                                  |
|:------:|:--------------------|:---------------------------------------------|
| `404`  | `TRANSFER_NOT_FOUND`| Transfer does not exist or belongs to another couple |

---

### 4. Update Transfer

All fields are optional (partial update). Omitted fields retain their current values.

| Item        | Value                       |
|:------------|:----------------------------|
| **Method**  | `PUT`                       |
| **Path**    | `/api/v1/transfers/{id}`    |
| **Auth**    | Required                    |

**Path Parameters**

| Parameter | Type   | Description     |
|:----------|:-------|:----------------|
| `id`      | `UUID` | Transfer ID     |

**Request Body** (`UpdateTransferRequest` — all fields optional, PatchValue pattern)

| Field                        | Type     | Constraints              | Description                               |
|:-----------------------------|:---------|:-------------------------|:------------------------------------------|
| `sourcePaymentMethodId`      | `UUID`   | Must differ from dest    | New source payment method ID              |
| `destinationPaymentMethodId` | `UUID`   | Must differ from source  | New destination payment method ID         |
| `amount`                     | `long`   | min=1, max=999999999     | New transfer amount in KRW                |
| `description`                | `string` | max=255                  | New short label (pass `null` to clear)    |
| `transferDate`               | `string` | `YYYY-MM-DD`             | New transfer date                         |
| `memo`                       | `string` |                          | New memo (pass `null` to clear)           |

**Response `200 OK`**: `ApiResponse<TransferResponse>`

**Error Responses**

| Status | Error Code                 | Description                                              |
|:------:|:---------------------------|:---------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`         | Invalid field values or source == destination            |
| `404`  | `TRANSFER_NOT_FOUND`       | Transfer does not exist or belongs to another couple     |
| `404`  | `PAYMENT_METHOD_NOT_FOUND` | Specified payment method does not exist                  |
| `403`  | `FORBIDDEN`                | Payment method belongs to another couple                 |

---

### 5. Delete Transfer

| Item        | Value                       |
|:------------|:----------------------------|
| **Method**  | `DELETE`                    |
| **Path**    | `/api/v1/transfers/{id}`    |
| **Auth**    | Required                    |
| **Returns** | `204 No Content`            |

**Path Parameters**

| Parameter | Type   | Description     |
|:----------|:-------|:----------------|
| `id`      | `UUID` | Transfer ID     |

**Error Responses**

| Status | Error Code           | Description                                  |
|:------:|:---------------------|:---------------------------------------------|
| `404`  | `TRANSFER_NOT_FOUND` | Transfer does not exist or belongs to another couple |

---

## Insurances

Insurance policy management for the couple. Each insurance record tracks a recurring premium payment. The `visibility` field follows the same `SHARED`/`PRIVATE` semantics used across other entities.

---

### 1. List Insurances

Returns all insurance records for the couple, optionally filtered by active status.

| Item        | Value                    |
|:------------|:-------------------------|
| **Method**  | `GET`                    |
| **Path**    | `/api/v1/insurances`     |
| **Auth**    | Required                 |

**Query Parameters**

| Parameter | Type      | Required | Description                                             |
|:----------|:----------|:--------:|:--------------------------------------------------------|
| `active`  | `boolean` | No       | When `true`, returns only active insurances. Omit for all. |

**Response `200 OK`**: `ApiResponse<List<InsuranceResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440300",
      "coupleId": "550e8400-e29b-41d4-a716-446655440001",
      "userId": "550e8400-e29b-41d4-a716-446655440000",
      "name": "삼성생명 종신보험",
      "insurer": "삼성생명",
      "insuranceType": "LIFE",
      "premiumAmount": 150000,
      "paymentDay": 25,
      "paymentCycle": "MONTHLY",
      "paymentMethodId": "550e8400-e29b-41d4-a716-446655440010",
      "categoryId": "550e8400-e29b-41d4-a716-446655440020",
      "startDate": "2023-01-01",
      "endDate": null,
      "memo": "종신 보험",
      "isActive": true,
      "visibility": "SHARED",
      "ownerId": null,
      "createdAt": "2026-03-01T10:00:00",
      "updatedAt": "2026-03-01T10:00:00"
    }
  ],
  "timestamp": "2026-03-28T10:00:00Z"
}
```

---

### 2. Create Insurance

Registers a new insurance policy for the couple.

| Item        | Value                    |
|:------------|:-------------------------|
| **Method**  | `POST`                   |
| **Path**    | `/api/v1/insurances`     |
| **Auth**    | Required                 |

**Request Body**: `InsuranceRequest`

| Field               | Type      | Required | Description                                                             |
|:--------------------|:----------|:--------:|:------------------------------------------------------------------------|
| `name`              | `string`  | Yes      | Insurance policy name (max 100 chars)                                   |
| `insurer`           | `string`  | No       | Insurance company name (max 100 chars)                                  |
| `insuranceType`     | `string`  | Yes      | One of: `LIFE`, `HEALTH`, `CAR`, `FIRE`, `ACCIDENT`, `OTHER`           |
| `premiumAmount`     | `long`    | Yes      | Monthly (or per-cycle) premium in KRW, must be > 0                     |
| `paymentDay`        | `integer` | No       | Day of month for payment (1–31)                                         |
| `paymentCycle`      | `string`  | No       | One of: `MONTHLY`, `QUARTERLY`, `SEMI_ANNUAL`, `YEARLY` (default: `MONTHLY`) |
| `paymentMethodId`   | `UUID`    | No       | Payment method used for premium deduction                               |
| `categoryId`        | `UUID`    | No       | Category to assign this insurance expense to                            |
| `startDate`         | `string`  | No       | Policy start date (`YYYY-MM-DD`)                                        |
| `endDate`           | `string`  | No       | Policy end date (`YYYY-MM-DD`), null if open-ended                      |
| `memo`              | `string`  | No       | Free-text memo                                                          |
| `visibility`        | `string`  | No       | `SHARED` or `PRIVATE` (default: `SHARED`)                              |

**Request Body Example**:

```json
{
  "name": "삼성생명 종신보험",
  "insurer": "삼성생명",
  "insuranceType": "LIFE",
  "premiumAmount": 150000,
  "paymentDay": 25,
  "paymentCycle": "MONTHLY",
  "paymentMethodId": "550e8400-e29b-41d4-a716-446655440010",
  "categoryId": "550e8400-e29b-41d4-a716-446655440020",
  "startDate": "2023-01-01",
  "memo": "종신 보험",
  "visibility": "SHARED"
}
```

**Response `201 Created`**: `ApiResponse<InsuranceResponse>`

**Error Responses**

| Status | Error Code             | Description                                      |
|:------:|:-----------------------|:-------------------------------------------------|
| `400`  | `VALIDATION_ERROR`     | Missing required fields or invalid enum value    |
| `404`  | `PAYMENT_METHOD_NOT_FOUND` | Specified paymentMethodId does not exist     |
| `404`  | `CATEGORY_NOT_FOUND`   | Specified categoryId does not exist              |

---

### 3. Update Insurance

Updates an existing insurance record. All fields are optional; only provided fields are updated.

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `PUT`                         |
| **Path**    | `/api/v1/insurances/{id}`     |
| **Auth**    | Required                      |

**Path Parameters**

| Parameter | Type   | Description    |
|:----------|:-------|:---------------|
| `id`      | `UUID` | Insurance ID   |

**Request Body**: `InsuranceUpdateRequest`

All fields are optional (use `PatchValue<T>` semantics — explicitly sending `null` clears a nullable field):

| Field               | Type      | Description                                                             |
|:--------------------|:----------|:------------------------------------------------------------------------|
| `name`              | `string`  | Insurance policy name (max 100 chars)                                   |
| `insurer`           | `string`  | Insurance company name (max 100 chars), nullable                        |
| `insuranceType`     | `string`  | One of: `LIFE`, `HEALTH`, `CAR`, `FIRE`, `ACCIDENT`, `OTHER`           |
| `premiumAmount`     | `long`    | Premium amount in KRW, must be > 0                                      |
| `paymentDay`        | `integer` | Day of month for payment (1–31), nullable                               |
| `paymentCycle`      | `string`  | One of: `MONTHLY`, `QUARTERLY`, `SEMI_ANNUAL`, `YEARLY`                |
| `paymentMethodId`   | `UUID`    | Payment method ID, nullable                                             |
| `categoryId`        | `UUID`    | Category ID, nullable                                                   |
| `startDate`         | `string`  | Policy start date (`YYYY-MM-DD`), nullable                              |
| `endDate`           | `string`  | Policy end date (`YYYY-MM-DD`), nullable                                |
| `memo`              | `string`  | Free-text memo, nullable                                                |
| `isActive`          | `boolean` | Set to `false` to deactivate the policy                                 |
| `visibility`        | `string`  | `SHARED` or `PRIVATE`                                                   |

**Response `200 OK`**: `ApiResponse<InsuranceResponse>`

**Error Responses**

| Status | Error Code               | Description                                         |
|:------:|:-------------------------|:----------------------------------------------------|
| `404`  | `INSURANCE_NOT_FOUND`    | Insurance does not exist or belongs to another couple |
| `400`  | `VALIDATION_ERROR`       | Invalid field value                                 |
| `403`  | `PRIVATE_ACCESS_DENIED`  | Insurance is PRIVATE and caller is not the owner    |

---

### 4. Delete Insurance

Deletes an insurance record permanently.

| Item        | Value                         |
|:------------|:------------------------------|
| **Method**  | `DELETE`                      |
| **Path**    | `/api/v1/insurances/{id}`     |
| **Auth**    | Required                      |

**Path Parameters**

| Parameter | Type   | Description    |
|:----------|:-------|:---------------|
| `id`      | `UUID` | Insurance ID   |

**Response `200 OK`**: `ApiResponse<Unit>`

**Error Responses**

| Status | Error Code              | Description                                         |
|:------:|:------------------------|:----------------------------------------------------|
| `404`  | `INSURANCE_NOT_FOUND`   | Insurance does not exist or belongs to another couple |
| `403`  | `PRIVATE_ACCESS_DENIED` | Insurance is PRIVATE and caller is not the owner    |

---

### 5. Insurance Summary

Returns a monthly summary of insurance premiums, accounting for each policy's payment cycle. Only active insurances are included in the totals.

| Item        | Value                           |
|:------------|:--------------------------------|
| **Method**  | `GET`                           |
| **Path**    | `/api/v1/insurances/summary`    |
| **Auth**    | Required                        |

**Query Parameters**

| Parameter | Type      | Required | Description          |
|:----------|:----------|:--------:|:---------------------|
| `year`    | `integer` | Yes      | Year (e.g., `2026`)  |
| `month`   | `integer` | Yes      | Month 1–12           |

**Response `200 OK`**: `ApiResponse<InsuranceSummaryResponse>`

```json
{
  "success": true,
  "data": {
    "year": 2026,
    "month": 3,
    "totalPremium": 350000,
    "activeCount": 3,
    "items": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440300",
        "name": "삼성생명 종신보험",
        "insuranceType": "LIFE",
        "premiumAmount": 150000,
        "paymentCycle": "MONTHLY",
        "paymentDay": 25,
        "isActive": true
      }
    ]
  },
  "timestamp": "2026-03-28T10:00:00Z"
}
```

**InsuranceSummaryResponse Fields**

| Field          | Type      | Description                                              |
|:---------------|:----------|:---------------------------------------------------------|
| `year`         | `integer` | Queried year                                             |
| `month`        | `integer` | Queried month                                            |
| `totalPremium` | `long`    | Sum of premiums due in the given month (cycle-adjusted)  |
| `activeCount`  | `integer` | Number of active insurance policies                      |
| `items`        | `array`   | List of summary items per policy                         |

**Error Responses**

| Status | Error Code         | Description                     |
|:------:|:-------------------|:--------------------------------|
| `400`  | `VALIDATION_ERROR` | Missing or invalid year/month   |

---

## Preferences (Favorites)

Couple-level preferences for quickly accessing frequently used categories and payment methods. The favorites list is shared across both partners (one record per couple stored in `couple_preferences`).

---

### 1. Get Favorites

Returns the current favorites for the authenticated user's couple.

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `GET`                              |
| **Path**    | `/api/v1/preferences/favorites`    |
| **Auth**    | Required                           |

**Response `200 OK`**: `ApiResponse<FavoritesResponse>`

```json
{
  "success": true,
  "data": {
    "categoryIds": [
      "550e8400-e29b-41d4-a716-446655440020",
      "550e8400-e29b-41d4-a716-446655440021"
    ],
    "paymentMethodIds": [
      "550e8400-e29b-41d4-a716-446655440010"
    ]
  },
  "timestamp": "2026-03-28T10:00:00Z"
}
```

**FavoritesResponse Fields**

| Field              | Type         | Description                                   |
|:-------------------|:-------------|:----------------------------------------------|
| `categoryIds`      | `UUID[]`     | Ordered list of favorite category IDs         |
| `paymentMethodIds` | `UUID[]`     | Ordered list of favorite payment method IDs   |

> If no preferences record exists yet for the couple, returns empty arrays.

---

### 2. Update Favorites

Replaces the entire favorites list for the couple. Use this for bulk updates (e.g., drag-and-drop reordering).

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `PUT`                              |
| **Path**    | `/api/v1/preferences/favorites`    |
| **Auth**    | Required                           |

**Request Body**: `FavoritesRequest`

| Field              | Type     | Required | Description                                      |
|:-------------------|:---------|:--------:|:-------------------------------------------------|
| `categoryIds`      | `UUID[]` | Yes      | Full ordered list of favorite category IDs       |
| `paymentMethodIds` | `UUID[]` | Yes      | Full ordered list of favorite payment method IDs |

**Request Body Example**:

```json
{
  "categoryIds": [
    "550e8400-e29b-41d4-a716-446655440020",
    "550e8400-e29b-41d4-a716-446655440021"
  ],
  "paymentMethodIds": [
    "550e8400-e29b-41d4-a716-446655440010"
  ]
}
```

**Response `200 OK`**: `ApiResponse<FavoritesResponse>`

**Error Responses**

| Status | Error Code         | Description                                           |
|:------:|:-------------------|:------------------------------------------------------|
| `400`  | `VALIDATION_ERROR` | Non-UUID values in arrays                             |
| `404`  | `COUPLE_NOT_FOUND` | Authenticated user is not in an active couple         |

---

### 3. Toggle Favorite

Adds or removes a single item from the favorites list. If the item is already a favorite, it is removed; otherwise it is added.

| Item        | Value                                      |
|:------------|:-------------------------------------------|
| **Method**  | `POST`                                     |
| **Path**    | `/api/v1/preferences/favorites/toggle`     |
| **Auth**    | Required                                   |

**Request Body**: `FavoriteToggleRequest`

| Field    | Type     | Required | Description                                    |
|:---------|:---------|:--------:|:-----------------------------------------------|
| `type`   | `string` | Yes      | `CATEGORY` or `PAYMENT_METHOD`                 |
| `itemId` | `UUID`   | Yes      | ID of the category or payment method to toggle |

**Request Body Example**:

```json
{
  "type": "CATEGORY",
  "itemId": "550e8400-e29b-41d4-a716-446655440022"
}
```

**Response `200 OK`**: `ApiResponse<FavoritesResponse>`

Returns the updated full favorites list after the toggle.

**Error Responses**

| Status | Error Code             | Description                                           |
|:------:|:-----------------------|:------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`     | Missing fields or invalid `type` value                |
| `404`  | `COUPLE_NOT_FOUND`     | Authenticated user is not in an active couple         |
| `404`  | `CATEGORY_NOT_FOUND`   | Specified category does not exist (for CATEGORY type) |
| `404`  | `PAYMENT_METHOD_NOT_FOUND` | Specified payment method does not exist           |

---

## Spending Plans

Spending plan management for the couple. A spending plan represents a future intended expense, which can be linked to an actual transaction upon completion. Plans support optional recurrence (`WEEKLY` or `MONTHLY`) and follow the same `SHARED`/`PRIVATE` visibility semantics used by other entities.

A plan with `status: "WISHLIST"` represents an unprioritized purchase idea that has no fixed date. Wishlist items may be promoted to `PLANNED` via the assign endpoint, which sets a `targetDate` and optionally a `weekNumber` and `budgetId`.

---

### 1. List Spending Plans

Returns spending plans for the couple, optionally filtered by date range and status.

| Item        | Value                          |
|:------------|:-------------------------------|
| **Method**  | `GET`                          |
| **Path**    | `/api/v1/spending-plans`       |
| **Auth**    | Required                       |

**Query Parameters**

| Parameter   | Type     | Required | Description                                                            |
|:------------|:---------|:--------:|:-----------------------------------------------------------------------|
| `startDate` | `string` | No       | Filter plans with `target_date >= startDate` (`YYYY-MM-DD`); ignored for WISHLIST plans |
| `endDate`   | `string` | No       | Filter plans with `target_date <= endDate` (`YYYY-MM-DD`); ignored for WISHLIST plans   |
| `status`    | `string` | No       | Comma-separated status values: `WISHLIST`, `PLANNED`, `COMPLETED`, `SKIPPED`, `OVERDUE` |

**Response `200 OK`**: `ApiResponse<SpendingPlanListResponse>`

```json
{
  "success": true,
  "data": {
    "plans": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440400",
        "name": "봄 옷 구매",
        "amount": 150000,
        "targetDate": "2026-03-29",
        "memo": "백화점 할인 기간",
        "category": {
          "id": "550e8400-e29b-41d4-a716-446655440020",
          "name": "의류",
          "icon": "👔"
        },
        "paymentMethod": {
          "id": "550e8400-e29b-41d4-a716-446655440010",
          "name": "현대카드"
        },
        "budgetId": null,
        "linkedTransactionId": null,
        "status": "PLANNED",
        "actualAmount": null,
        "completedDate": null,
        "isRecurring": false,
        "frequency": null,
        "visibility": "SHARED",
        "authorName": "홍길동",
        "priority": "MEDIUM",
        "estimatedMin": null,
        "estimatedMax": null,
        "tags": null,
        "weekNumber": null,
        "createdAt": "2026-03-25T10:00:00"
      }
    ],
    "summary": {
      "totalPlanned": 150000,
      "totalCompleted": 0,
      "totalSkipped": 0,
      "plannedCount": 1,
      "completedCount": 0,
      "overdueCount": 0
    }
  },
  "timestamp": "2026-03-28T10:00:00Z"
}
```

**SpendingPlanListResponse Fields**

| Field     | Type                        | Description                              |
|:----------|:----------------------------|:-----------------------------------------|
| `plans`   | `SpendingPlanResponse[]`    | List of spending plans                   |
| `summary` | `SpendingPlanSummary`       | Aggregate totals for the returned plans  |

**SpendingPlanSummary Fields**

| Field            | Type      | Description                                      |
|:-----------------|:----------|:-------------------------------------------------|
| `totalPlanned`   | `long`    | Sum of `amount` for plans with status `PLANNED`  |
| `totalCompleted` | `long`    | Sum of `actualAmount` for `COMPLETED` plans      |
| `totalSkipped`   | `long`    | Sum of `amount` for plans with status `SKIPPED`  |
| `plannedCount`   | `integer` | Number of plans with status `PLANNED`            |
| `completedCount` | `integer` | Number of plans with status `COMPLETED`          |
| `overdueCount`   | `integer` | Number of plans with status `OVERDUE`            |

**SpendingPlanResponse Fields**

| Field                 | Type               | Description                                                                    |
|:----------------------|:-------------------|:-------------------------------------------------------------------------------|
| `id`                  | `UUID`             | Spending plan ID                                                               |
| `name`                | `string`           | Plan name (max 100 chars)                                                      |
| `amount`              | `long`             | Planned amount in KRW                                                          |
| `targetDate`          | `string?`          | Intended spending date (`YYYY-MM-DD`); null for `WISHLIST` plans               |
| `memo`                | `string?`          | Optional memo                                                                  |
| `category`            | `CategorySummary?` | Associated category (id, name, icon), or null                                  |
| `paymentMethod`       | `PaymentMethodSummary?` | Associated payment method (id, name), or null                             |
| `budgetId`            | `UUID?`            | Associated monthly budget ID, or null                                          |
| `linkedTransactionId` | `UUID?`            | Transaction linked on completion, or null                                      |
| `status`              | `string`           | One of: `WISHLIST`, `PLANNED`, `COMPLETED`, `SKIPPED`, `OVERDUE`              |
| `actualAmount`        | `long?`            | Actual amount spent (set on completion), or null                               |
| `completedDate`       | `string?`          | Date the plan was completed (`YYYY-MM-DD`), or null                            |
| `isRecurring`         | `boolean`          | Whether the plan generates future recurring instances                          |
| `frequency`           | `string?`          | Recurrence frequency: `WEEKLY` or `MONTHLY`, or null                          |
| `visibility`          | `string`           | `SHARED` or `PRIVATE`                                                          |
| `authorName`          | `string`           | Display name of the user who created the plan                                  |
| `priority`            | `string`           | Priority level: `HIGH`, `MEDIUM`, or `LOW` (default: `MEDIUM`)                |
| `estimatedMin`        | `long?`            | Lower bound of estimated price range in KRW, or null                          |
| `estimatedMax`        | `long?`            | Upper bound of estimated price range in KRW, or null                          |
| `tags`                | `string?`          | Comma-separated tag string (e.g. `"여행,생일"`), or null                       |
| `weekNumber`          | `integer?`         | Week-of-month assignment (1–6) used for weekly scheduling, or null             |
| `createdAt`           | `string`           | ISO-8601 creation timestamp                                                    |

---

### 2. Create Spending Plan

Creates a new spending plan for the couple. If `isRecurring` is true, the backend generates the next recurrence instance automatically when this plan is completed or skipped.

| Item        | Value                          |
|:------------|:-------------------------------|
| **Method**  | `POST`                         |
| **Path**    | `/api/v1/spending-plans`       |
| **Auth**    | Required                       |

**Request Body**: `CreateSpendingPlanRequest`

| Field             | Type      | Required | Description                                                                              |
|:------------------|:----------|:--------:|:-----------------------------------------------------------------------------------------|
| `name`            | `string`  | Yes      | Plan name (max 100 chars)                                                                |
| `amount`          | `long`    | Yes      | Planned amount in KRW (must be > 0)                                                      |
| `status`          | `string?` | No       | Initial status: `WISHLIST` or `PLANNED` (default: `PLANNED`)                             |
| `targetDate`      | `string?` | No       | Intended spending date (`YYYY-MM-DD`); required when `status` is `PLANNED`               |
| `memo`            | `string?` | No       | Optional memo                                                                            |
| `categoryId`      | `UUID?`   | No       | Category to associate                                                                    |
| `paymentMethodId` | `UUID?`   | No       | Payment method to associate                                                              |
| `budgetId`        | `UUID?`   | No       | Monthly budget to associate                                                              |
| `isRecurring`     | `boolean?`| No       | Whether to generate recurring instances (default: `false`)                               |
| `frequency`       | `string?` | No       | Required when `isRecurring` is `true`: `WEEKLY` or `MONTHLY`                            |
| `visibility`      | `string?` | No       | `SHARED` or `PRIVATE` (default: `SHARED`)                                               |
| `priority`        | `string?` | No       | `HIGH`, `MEDIUM`, or `LOW` (default: `MEDIUM`)                                          |
| `estimatedMin`    | `long?`   | No       | Lower bound of estimated price range in KRW                                              |
| `estimatedMax`    | `long?`   | No       | Upper bound of estimated price range in KRW                                              |
| `tags`            | `string?` | No       | Comma-separated tag string (e.g. `"여행,생일"`)                                          |
| `weekNumber`      | `integer?`| No       | Week-of-month assignment (1–6)                                                           |

**Request Body Example**:

```json
{
  "name": "봄 옷 구매",
  "amount": 150000,
  "status": "PLANNED",
  "targetDate": "2026-03-29",
  "memo": "백화점 할인 기간",
  "categoryId": "550e8400-e29b-41d4-a716-446655440020",
  "paymentMethodId": "550e8400-e29b-41d4-a716-446655440010",
  "isRecurring": false,
  "visibility": "SHARED",
  "priority": "MEDIUM",
  "estimatedMin": null,
  "estimatedMax": null,
  "tags": null,
  "weekNumber": null
}
```

**Response `201 Created`**: `ApiResponse<SpendingPlanResponse>`

**Error Responses**

| Status | Error Code              | Description                                          |
|:------:|:------------------------|:-----------------------------------------------------|
| `400`  | `VALIDATION_ERROR`      | Missing required fields or invalid values            |
| `404`  | `CATEGORY_NOT_FOUND`    | Specified `categoryId` does not exist                |
| `404`  | `PAYMENT_METHOD_NOT_FOUND` | Specified `paymentMethodId` does not exist        |
| `404`  | `BUDGET_NOT_FOUND`      | Specified `budgetId` does not exist                  |

---

### 3. Update Spending Plan

Updates an existing spending plan. All fields are optional; only the provided fields are changed (patch semantics via `PatchValue`).

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `PUT`                              |
| **Path**    | `/api/v1/spending-plans/{id}`      |
| **Auth**    | Required                           |

**Path Parameters**

| Parameter | Type   | Description          |
|:----------|:-------|:---------------------|
| `id`      | `UUID` | Spending plan ID     |

**Request Body**: `UpdateSpendingPlanRequest` (all fields optional)

| Field             | Type      | Description                                                                    |
|:------------------|:----------|:-------------------------------------------------------------------------------|
| `name`            | `string?` | Updated plan name (max 100 chars)                                              |
| `amount`          | `long?`   | Updated planned amount in KRW                                                  |
| `targetDate`      | `string?` | Updated target date (`YYYY-MM-DD`; pass `null` explicitly to clear for WISHLIST) |
| `memo`            | `string?` | Updated memo (pass `null` explicitly to clear)                                 |
| `categoryId`      | `UUID?`   | Updated category (pass `null` explicitly to clear)                             |
| `paymentMethodId` | `UUID?`   | Updated payment method (pass `null` explicitly to clear)                       |
| `budgetId`        | `UUID?`   | Updated budget (pass `null` explicitly to clear)                               |
| `isRecurring`     | `boolean?`| Updated recurrence flag                                                        |
| `frequency`       | `string?` | Updated frequency (`WEEKLY` or `MONTHLY`)                                      |
| `visibility`      | `string?` | Updated visibility (`SHARED` or `PRIVATE`)                                     |
| `priority`        | `string?` | Updated priority: `HIGH`, `MEDIUM`, or `LOW`                                   |
| `estimatedMin`    | `long?`   | Updated lower bound of estimated price range (pass `null` to clear)            |
| `estimatedMax`    | `long?`   | Updated upper bound of estimated price range (pass `null` to clear)            |
| `tags`            | `string?` | Updated comma-separated tag string (pass `null` to clear)                      |
| `weekNumber`      | `integer?`| Updated week-of-month assignment 1–6 (pass `null` to clear)                   |

**Response `200 OK`**: `ApiResponse<SpendingPlanResponse>`

**Error Responses**

| Status | Error Code                 | Description                                              |
|:------:|:---------------------------|:---------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`         | Invalid field values                                     |
| `403`  | `PRIVATE_ACCESS_DENIED`    | Plan is `PRIVATE` and caller is not the owner            |
| `404`  | `SPENDING_PLAN_NOT_FOUND`  | Spending plan does not exist or belongs to another couple |
| `404`  | `CATEGORY_NOT_FOUND`       | Specified `categoryId` does not exist                    |
| `404`  | `PAYMENT_METHOD_NOT_FOUND` | Specified `paymentMethodId` does not exist               |

---

### 4. Delete Spending Plan

Deletes a spending plan. Only the author or either partner (for `SHARED` plans) may delete.

| Item        | Value                              |
|:------------|:-----------------------------------|
| **Method**  | `DELETE`                           |
| **Path**    | `/api/v1/spending-plans/{id}`      |
| **Auth**    | Required                           |

**Path Parameters**

| Parameter | Type   | Description      |
|:----------|:-------|:-----------------|
| `id`      | `UUID` | Spending plan ID |

**Response `200 OK`**: `ApiResponse<Unit>`

**Error Responses**

| Status | Error Code                | Description                                               |
|:------:|:--------------------------|:----------------------------------------------------------|
| `403`  | `PRIVATE_ACCESS_DENIED`   | Plan is `PRIVATE` and caller is not the owner             |
| `404`  | `SPENDING_PLAN_NOT_FOUND` | Spending plan does not exist or belongs to another couple |

---

### 5. Complete Spending Plan

Marks a spending plan as `COMPLETED`. Optionally links an existing transaction and records the actual amount spent.

| Item        | Value                                      |
|:------------|:-------------------------------------------|
| **Method**  | `PATCH`                                    |
| **Path**    | `/api/v1/spending-plans/{id}/complete`     |
| **Auth**    | Required                                   |

**Path Parameters**

| Parameter | Type   | Description      |
|:----------|:-------|:-----------------|
| `id`      | `UUID` | Spending plan ID |

**Request Body**: `CompleteSpendingPlanRequest`

| Field                 | Type    | Required | Description                                                                     |
|:----------------------|:--------|:--------:|:--------------------------------------------------------------------------------|
| `linkedTransactionId` | `UUID?` | No       | Existing transaction to link to this plan                                       |
| `actualAmount`        | `long?` | No       | Actual amount spent; defaults to the plan's `amount` if omitted                 |

**Request Body Example**:

```json
{
  "linkedTransactionId": "550e8400-e29b-41d4-a716-446655440500",
  "actualAmount": 143000
}
```

**Response `200 OK`**: `ApiResponse<SpendingPlanResponse>`

The returned plan has `status: "COMPLETED"`, `completedDate` set to today, and `actualAmount` populated.

**Error Responses**

| Status | Error Code                | Description                                               |
|:------:|:--------------------------|:----------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`        | Plan is already completed or skipped                      |
| `404`  | `SPENDING_PLAN_NOT_FOUND` | Spending plan does not exist or belongs to another couple |
| `404`  | `TRANSACTION_NOT_FOUND`   | Specified `linkedTransactionId` does not exist            |

---

### 6. Skip Spending Plan

Marks a spending plan as `SKIPPED`. The plan is retained for history but excluded from budget tracking.

| Item        | Value                                   |
|:------------|:----------------------------------------|
| **Method**  | `PATCH`                                 |
| **Path**    | `/api/v1/spending-plans/{id}/skip`      |
| **Auth**    | Required                                |

**Path Parameters**

| Parameter | Type   | Description      |
|:----------|:-------|:-----------------|
| `id`      | `UUID` | Spending plan ID |

**Response `200 OK`**: `ApiResponse<SpendingPlanResponse>`

**Error Responses**

| Status | Error Code                | Description                                               |
|:------:|:--------------------------|:----------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`        | Plan is already completed or skipped                      |
| `404`  | `SPENDING_PLAN_NOT_FOUND` | Spending plan does not exist or belongs to another couple |

---

### 7. Spending Plan Suggestions

Returns `PLANNED` spending plans that closely match an incoming transaction (by category and amount proximity), to allow the user to link the transaction to an existing plan at creation time.

| Item        | Value                                   |
|:------------|:----------------------------------------|
| **Method**  | `GET`                                   |
| **Path**    | `/api/v1/spending-plans/suggestions`    |
| **Auth**    | Required                                |

**Query Parameters**

| Parameter    | Type     | Required | Description                                                    |
|:-------------|:---------|:--------:|:---------------------------------------------------------------|
| `categoryId` | `UUID`   | No       | Match plans associated with this category                      |
| `amount`     | `long`   | No       | Transaction amount used to score plans by amount proximity     |
| `date`       | `string` | No       | Transaction date (`YYYY-MM-DD`); used to find plans near this date |

**Response `200 OK`**: `ApiResponse<List<SpendingPlanSuggestion>>`

```json
{
  "success": true,
  "data": [
    {
      "planId": "550e8400-e29b-41d4-a716-446655440400",
      "name": "봄 옷 구매",
      "plannedAmount": 150000,
      "matchScore": 0.93
    }
  ],
  "timestamp": "2026-03-28T10:00:00Z"
}
```

**SpendingPlanSuggestion Fields**

| Field           | Type     | Description                                                          |
|:----------------|:---------|:---------------------------------------------------------------------|
| `planId`        | `UUID`   | Spending plan ID                                                     |
| `name`          | `string` | Plan name                                                            |
| `plannedAmount` | `long`   | Original planned amount in KRW                                       |
| `matchScore`    | `double` | Relevance score between 0.0 and 1.0 (higher = better match); sorted descending |

---

### 8. List Wishlist

Returns all spending plans with `status: "WISHLIST"` for the couple, sorted by priority descending (`HIGH` first) then by creation date descending.

| Item        | Value                                   |
|:------------|:----------------------------------------|
| **Method**  | `GET`                                   |
| **Path**    | `/api/v1/spending-plans/wishlist`       |
| **Auth**    | Required                                |

**Response `200 OK`**: `ApiResponse<List<SpendingPlanResponse>>`

```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440401",
      "name": "에어팟 프로",
      "amount": 350000,
      "targetDate": null,
      "memo": "할인할 때 구매",
      "category": null,
      "paymentMethod": null,
      "budgetId": null,
      "linkedTransactionId": null,
      "status": "WISHLIST",
      "actualAmount": null,
      "completedDate": null,
      "isRecurring": false,
      "frequency": null,
      "visibility": "SHARED",
      "authorName": "홍길동",
      "priority": "HIGH",
      "estimatedMin": 300000,
      "estimatedMax": 380000,
      "tags": "전자기기,선물",
      "weekNumber": null,
      "createdAt": "2026-03-25T10:00:00"
    }
  ],
  "timestamp": "2026-03-28T10:00:00Z"
}
```

**Error Responses**

| Status | Error Code         | Description                                        |
|:------:|:-------------------|:---------------------------------------------------|
| `404`  | `COUPLE_NOT_FOUND` | Authenticated user is not in an active couple      |

---

### 9. Assign Spending Plan

Promotes a `WISHLIST` plan to `PLANNED` by assigning a target date. Optionally assigns a week number and monthly budget. Only plans with `status: "WISHLIST"` may be assigned; other statuses return `INVALID_STATUS`.

| Item        | Value                                        |
|:------------|:---------------------------------------------|
| **Method**  | `PATCH`                                      |
| **Path**    | `/api/v1/spending-plans/{id}/assign`         |
| **Auth**    | Required                                     |

**Path Parameters**

| Parameter | Type   | Description      |
|:----------|:-------|:-----------------|
| `id`      | `UUID` | Spending plan ID |

**Request Body**: `AssignSpendingPlanRequest`

| Field        | Type      | Required | Description                                                           |
|:-------------|:----------|:--------:|:----------------------------------------------------------------------|
| `targetDate` | `string`  | Yes      | Date to schedule the plan (`YYYY-MM-DD`)                              |
| `weekNumber` | `integer?`| No       | Week-of-month assignment (1–6)                                        |
| `budgetId`   | `UUID?`   | No       | Monthly budget to associate with the plan                             |

**Request Body Example**:

```json
{
  "targetDate": "2026-04-10",
  "weekNumber": 2,
  "budgetId": "550e8400-e29b-41d4-a716-446655440300"
}
```

**Response `200 OK`**: `ApiResponse<SpendingPlanResponse>`

The returned plan has `status: "PLANNED"`, `targetDate` set to the provided value, and `weekNumber`/`budgetId` updated if supplied.

**Error Responses**

| Status | Error Code                | Description                                                   |
|:------:|:--------------------------|:--------------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`        | Missing required `targetDate` or invalid `weekNumber` value   |
| `400`  | `INVALID_STATUS`          | Plan status is not `WISHLIST`; only wishlist items can be assigned |
| `404`  | `SPENDING_PLAN_NOT_FOUND` | Spending plan does not exist or belongs to another couple     |
| `404`  | `BUDGET_NOT_FOUND`        | Specified `budgetId` does not exist                           |

---

### 10. Complete with Transaction

Marks a spending plan as `COMPLETED` and simultaneously creates a new `EXPENSE` transaction linked to the plan. This is a convenience endpoint that avoids requiring a separate transaction creation step. The created transaction is automatically linked to the plan via `linkedTransactionId`.

| Item        | Value                                                      |
|:------------|:-----------------------------------------------------------|
| **Method**  | `PATCH`                                                    |
| **Path**    | `/api/v1/spending-plans/{id}/complete-with-transaction`    |
| **Auth**    | Required                                                   |

**Path Parameters**

| Parameter | Type   | Description      |
|:----------|:-------|:-----------------|
| `id`      | `UUID` | Spending plan ID |

**Request Body**: `CompleteWithTransactionRequest`

| Field             | Type      | Required | Description                                                            |
|:------------------|:----------|:--------:|:-----------------------------------------------------------------------|
| `amount`          | `long`    | Yes      | Actual amount spent in KRW (must be > 0); used as both `actualAmount` on the plan and the transaction amount |
| `transactionDate` | `string`  | Yes      | Date of the transaction (`YYYY-MM-DD`)                                 |
| `description`     | `string?` | No       | Transaction description; defaults to the plan name if omitted          |
| `categoryId`      | `UUID?`   | No       | Category for the new transaction; defaults to the plan's category if omitted |
| `paymentMethodId` | `UUID?`   | No       | Payment method for the new transaction; defaults to the plan's payment method if omitted |

**Request Body Example**:

```json
{
  "amount": 143000,
  "transactionDate": "2026-04-10",
  "description": "에어팟 프로 구매",
  "categoryId": "550e8400-e29b-41d4-a716-446655440020",
  "paymentMethodId": "550e8400-e29b-41d4-a716-446655440010"
}
```

**Response `200 OK`**: `ApiResponse<SpendingPlanResponse>`

The returned plan has `status: "COMPLETED"`, `completedDate` set to `transactionDate`, `actualAmount` set to `amount`, and `linkedTransactionId` pointing to the newly created transaction.

**Error Responses**

| Status | Error Code                | Description                                                        |
|:------:|:--------------------------|:-------------------------------------------------------------------|
| `400`  | `VALIDATION_ERROR`        | Missing required fields or invalid values                          |
| `400`  | `INVALID_STATUS`          | Plan is already `COMPLETED` or `SKIPPED`                           |
| `404`  | `SPENDING_PLAN_NOT_FOUND` | Spending plan does not exist or belongs to another couple          |
| `404`  | `CATEGORY_NOT_FOUND`      | Specified `categoryId` does not exist                              |
| `404`  | `PAYMENT_METHOD_NOT_FOUND`| Specified `paymentMethodId` does not exist                         |

---

## Infrastructure

Health and observability endpoints. Both are publicly accessible (`permitAll()` in `SecurityConfig`) and require no authentication.

---

### 1. Health Check

Application-level liveness check. Returns a simple `OK` string (not wrapped in `ApiResponse`).

| Item        | Value                     |
|:------------|:--------------------------|
| **Method**  | `GET`                     |
| **Path**    | `/api/v1/health`          |
| **Auth**    | None (public)             |

**Response `200 OK`**: Plain text

```
OK
```

---

### 2. Actuator Health

Spring Boot Actuator health endpoint. Returns detailed status including database connectivity. Used by deployment pipelines to verify the application is healthy after deploy.

| Item        | Value                     |
|:------------|:--------------------------|
| **Method**  | `GET`                     |
| **Path**    | `/actuator/health`        |
| **Auth**    | None (public)             |

**Response `200 OK`**:

```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 107374182400,
        "free": 53687091200,
        "threshold": 10485760,
        "exists": true
      }
    },
    "ping": {
      "status": "UP"
    }
  }
}
```

**Response `503 Service Unavailable`**: Returned when one or more components report `DOWN` (e.g., database unreachable).

---

## WebSocket (STOMP)

Real-time synchronization between couple members uses STOMP over WebSocket. When one partner creates, updates, or deletes a shared entity, the server publishes an event to the couple's topic so the other partner's client can update its local state immediately.

---

### Connection

| Item            | Value                                                      |
|:----------------|:-----------------------------------------------------------|
| **Endpoint**    | `wss://{host}/ws`                                          |
| **Protocol**    | STOMP over WebSocket                                       |
| **Auth**        | STOMP `CONNECT` frame header: `Authorization: Bearer {accessToken}` |
| **Heartbeat**   | client→server 10s, server→client 10s                      |

**STOMP CONNECT frame example**:

```
CONNECT
Authorization:Bearer {accessToken}
accept-version:1.1,1.2
heart-beat:10000,10000

^@
```

---

### Subscription Topics

| Topic                            | Description                                    |
|:---------------------------------|:-----------------------------------------------|
| `/topic/couple/{coupleId}`       | All sync events for a couple (both partners subscribe to this topic) |

**STOMP SUBSCRIBE frame example**:

```
SUBSCRIBE
id:sub-0
destination:/topic/couple/{coupleId}

^@
```

---

### Event Payload Schema

All messages published to a couple topic share the following JSON structure:

```json
{
  "type": "TRANSACTION_CREATED",
  "entityId": "uuid",
  "coupleId": "uuid",
  "authorId": "uuid",
  "entityType": "TRANSACTION",
  "timestamp": "2026-03-12T10:00:00Z"
}
```

| Field        | Type     | Required | Description                                          |
|:-------------|:---------|:--------:|:-----------------------------------------------------|
| `type`       | `string` | Yes      | Event type (see Event Types table below)             |
| `entityId`   | `uuid`   | Yes      | ID of the affected entity                            |
| `coupleId`   | `uuid`   | Yes      | ID of the couple the event belongs to                |
| `authorId`   | `uuid`   | Yes      | ID of the user who triggered the event               |
| `entityType` | `string` | Yes      | Category of entity (see Event Types table below)     |
| `timestamp`  | `string` | Yes      | ISO-8601 UTC timestamp of when the event occurred    |

---

### Event Types

| `entityType`     | `type` values                                                                                      |
|:-----------------|:---------------------------------------------------------------------------------------------------|
| `TRANSACTION`    | `TRANSACTION_CREATED`, `TRANSACTION_UPDATED`, `TRANSACTION_DELETED`                               |
| `BUDGET`         | `BUDGET_CREATED`, `BUDGET_UPDATED`, `BUDGET_DELETED`                                              |
| `CATEGORY`       | `CATEGORY_CREATED`, `CATEGORY_UPDATED`, `CATEGORY_DELETED`                                        |
| `CATEGORY_GROUP` | `CATEGORY_GROUP_CREATED`, `CATEGORY_GROUP_UPDATED`, `CATEGORY_GROUP_DELETED`                      |
| `PAYMENT_METHOD` | `PAYMENT_METHOD_CREATED`, `PAYMENT_METHOD_UPDATED`, `PAYMENT_METHOD_DELETED`                      |
| `POCKET`         | `POCKET_CREATED`, `POCKET_UPDATED`, `POCKET_DELETED`                                              |
| `POCKET_TRANSFER`| `POCKET_TRANSFER_CREATED`, `POCKET_DISTRIBUTED`                                                   |

Upon receiving an event, the frontend client should:
1. Check `coupleId` matches the authenticated session's couple.
2. Use `entityType` and `type` to determine which local cache or BLoC state to invalidate or update.
3. Optionally fetch the full entity via the corresponding REST endpoint using `entityId`.

---

## Redis Cache Strategy

The backend uses Upstash Redis (TLS) to cache frequently read data per couple, reducing database load. The connection is configured via `spring.data.redis.url=${REDIS_URL}`.

### Cache Keys

| Cache Key                    | TTL        | Cached Data                                        |
|:-----------------------------|:----------:|:---------------------------------------------------|
| `couple:{coupleId}`          | 10 minutes | Couple entity (members, status, metadata)          |
| `categories:{coupleId}`      | 10 minutes | Full category list for a couple (including groups) |
| `user:{userId}`              | 5 minutes  | User profile entity                                |

### Invalidation Rules

Cache entries are evicted on write operations to their respective entities:

| Write Operation                              | Invalidated Key(s)                                    |
|:---------------------------------------------|:------------------------------------------------------|
| Create / Update / Delete couple              | `couple:{coupleId}`                                   |
| Create / Update / Delete category            | `categories:{coupleId}`                               |
| Create / Update / Delete category group      | `categories:{coupleId}`                               |
| Update user profile                          | `user:{userId}`                                       |

### Connection Configuration

```yaml
spring:
  data:
    redis:
      url: ${REDIS_URL}   # Upstash Redis TLS URL (rediss://...)
```

> **Note**: Redis is used solely for read-through caching. It is not used as a message broker for WebSocket events; STOMP message routing is handled in-process by Spring's `SimpleMessageBroker`.

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
| `TRANSACTION_NOT_FOUND`           | `404`       | Requested transaction does not exist                 |
| `BUDGET_NOT_FOUND`                | `404`       | Requested budget does not exist                      |
| `DUPLICATE_BUDGET`                | `409`       | Budget for this category/group and month already exists |
| `GROUP_NOT_FOUND`                 | `404`       | Requested category group does not exist              |
| `PAYMENT_METHOD_NOT_FOUND`        | `404`       | Requested payment method does not exist              |
| `CANNOT_DELETE_DEFAULT_PAYMENT_METHOD` | `400`  | Default payment methods cannot be deleted            |
| `RECURRING_NOT_FOUND`             | `404`       | Requested recurring transaction does not exist       |
| `POCKET_NOT_FOUND`                | `404`       | Requested money pocket does not exist                |
| `POCKET_TRANSFER_NOT_FOUND`       | `404`       | Requested pocket transfer does not exist             |
| `TRANSFER_NOT_FOUND`              | `404`       | Requested transfer does not exist or belongs to another couple |
| `CREDIT_TO_CREDIT_TRANSFER_FORBIDDEN` | `400`   | Transfer between two CREDIT-type payment methods is not allowed |
| `LINKED_BANK_NOT_FOUND`           | `404`       | Specified linkedBankId does not exist or is not BANK type |
| `PRIVATE_ACCESS_DENIED`           | `403`       | The requested resource is PRIVATE and the caller is not the owner |
| `INSURANCE_NOT_FOUND`             | `404`       | Requested insurance does not exist or belongs to another couple |
| `SPENDING_PLAN_NOT_FOUND`         | `404`       | Requested spending plan does not exist or belongs to another couple |
| `INVALID_STATUS`                  | `400`       | The operation is not permitted for the plan's current status        |
