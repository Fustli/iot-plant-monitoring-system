# Missing API Endpoints Report

## Overview

This document identifies backend API endpoints that are **required by the Flutter frontend** but are either:
1. **Not implemented** (stub with `pass`)
2. **Missing entirely** from the backend
3. **Have incorrect permissions** for the intended use case

---

## 🔴 Critical - Blocking Features

### 1. Public User Registration

**Current State:**  
```python
@app.post("/api/auth/register")
async def register(
    payload: UserDetails,
    current_user: User = Depends(require_roles(["admin"])),  # ❌ Requires admin
):
```

**Problem:** Registration endpoint requires admin authentication. New users cannot self-register.

**Required:** A public registration endpoint for consumer users:
```python
@app.post("/api/auth/register/consumer")  # No auth required
async def register_consumer(payload: ConsumerRegistration):
    """
    Public registration for consumer users only.
    Manufacturers and admins must be created by existing admins.
    """
```

**Frontend Impact:** `RegistrationScreen` cannot function without this.

---

### 2. All Consumer Endpoints (Stub Only)

The following endpoints exist but contain only `pass`:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/consumer/plant-types` | GET | List available plant types |
| `/api/consumer/my-plants` | GET | List user's plants |
| `/api/consumer/plant-from-scratch` | POST | Create custom plant |
| `/api/consumer/plant-from-database` | POST | Create plant from catalog |
| `/api/consumer/my-plants/{id}` | GET | Get single plant details |
| `/api/consumer/my-plants/{id}` | PUT | Update plant |
| `/api/consumer/my-plants/{id}` | DELETE | Delete plant |
| `/api/consumer/my-plants/activation` | POST | Toggle plant active state |
| `/api/consumer/devices/register` | POST | Register device by unique ID |
| `/api/consumer/my-devices` | GET | List user's devices |
| `/api/consumer/my-devices/activation` | POST | Toggle device active state |
| `/api/consumer/my-devices/{id}` | DELETE | Remove device |
| `/api/consumer/devices/{id}/history` | GET | Get sensor history |
| `/api/consumer/devices/{id}/command` | POST | Send device command |
| `/api/consumer/alerts/{user_id}` | GET | Get user alerts |

**Frontend Impact:** `UserDashboardScreen` cannot display real data.

---

### 3. All Manufacturer Endpoints (Stub Only)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/manufacturer/device-types` | GET | List manufacturer's device types |
| `/api/manufacturer/device-types` | POST | Register new device type |
| `/api/manufacturer/device-types/{id}` | PUT | Update device type |
| `/api/manufacturer/devices` | POST | Register device instance |

**Frontend Impact:** `ManufacturerDashboardScreen` cannot function.

---

### 4. Admin Endpoints (Stub Only)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/admin/system/status` | GET | System health info |
| `/api/admin/users` | GET | List all users |
| `/api/admin/users/{id}` | DELETE | Delete user |
| `/api/admin/devices` | GET | List all devices |
| `/api/plant-type` | POST | Add new plant type |
| `/api/plant-species/{id}` | PUT | Update plant type |
| `/api/plant-species/{id}` | DELETE | Delete plant type |

**Frontend Impact:** `AdminDashboardScreen` cannot manage users or catalog.

---

### 5. User Profile Endpoints (Stub Only)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/user/profile` | GET | Get current user profile |
| `/api/user/profile` | PUT | Update profile or delete account |

**Frontend Impact:** Profile editing unavailable.

---

## 🟡 Missing Endpoints

### 1. Plant Type Search

**Need:**
```python
@app.get("/api/consumer/plant-types/search")
async def search_plant_types(query: str, ...):
    """Search plant types by name or scientific name."""
```

**Frontend Use:** When adding a plant, users should be able to search the catalog.

---

### 2. Device Types List (Consumer View)

**Need:**
```python
@app.get("/api/consumer/available-device-types")
async def list_available_device_types(...):
    """List device types available for registration by consumers."""
```

**Current:** Only manufacturers can see device types. Consumers need this to understand what devices are compatible.

---

### 3. Password Change

**Need:**
```python
@app.post("/api/user/change-password")
async def change_password(old_password: str, new_password: str, ...):
    """Change user password."""
```

---

### 4. Forgot Password Flow

**Need:**
```python
@app.post("/api/auth/forgot-password")
async def forgot_password(email: str):
    """Initiate password reset flow."""

@app.post("/api/auth/reset-password")
async def reset_password(token: str, new_password: str):
    """Reset password with token."""
```

---

### 5. Alert Management

**Need:**
```python
@app.put("/api/consumer/alerts/{alert_id}/acknowledge")
async def acknowledge_alert(...):
    """Mark alert as acknowledged."""

@app.put("/api/consumer/alerts/{alert_id}/resolve")
async def resolve_alert(...):
    """Mark alert as resolved."""
```

---

## 🟢 Working Endpoints

| Endpoint | Status |
|----------|--------|
| `POST /api/auth/login` | ✅ Implemented |

---

## Implementation Priority

### Phase 1 - Core Functionality
1. **Public consumer registration** - Enable new user signups
2. **Consumer plant CRUD** - Full plant management
3. **Consumer device registration** - Device claiming

### Phase 2 - Data & Monitoring  
4. **Sensor history endpoint** - Charts and analytics
5. **Alert retrieval** - User notification

### Phase 3 - Administration
6. **Admin user management** - CRUD operations
7. **Admin plant catalog** - Species management
8. **System status** - Health monitoring

### Phase 4 - Manufacturer Portal
9. **Device type management** - Full CRUD
10. **Device instance registration** - Serial number tracking

---

## Schema Requirements

### ConsumerRegistration (Missing)
```python
class ConsumerRegistration(BaseModel):
    username: str
    email: EmailStr
    password: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
```

### PlantTypeSearchParams (Missing)
```python
class PlantTypeSearchParams(BaseModel):
    query: Optional[str] = None
    page: int = 1
    per_page: int = 20
```

---

## Notes

- All endpoints returning lists should support pagination
- Consider adding rate limiting for public endpoints
- Add proper validation error responses (422) with i18n support
- Device registration should validate unique_id format

---

*Generated: $(date)*  
*Frontend Version: 1.0.0*
