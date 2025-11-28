# Missing API Endpoints Report

## Overview

This document identifies backend API endpoints that are **NOT YET IMPLEMENTED** (stub-only or missing) for the Flutter frontend.

**Last Updated:** November 28, 2025

---

## Status Summary

| Category | Stub/Missing |
|----------|--------------|
| Authentication | 6 |
| User Profile | 2 |
| Admin | 1 |
| Manufacturer | 3 |
| Plant Catalog (Admin) | 2 |
| Consumer Plants | 3 |
| Consumer Devices | 2 |
| Monitoring & Alerts | 5 |
| **Total Missing** | **24** |

---

## ⚠️ Stub-Only Endpoints (Defined but return `pass`)

### Authentication (6 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/auth/register` | POST | Admin creates users | Medium |
| `/api/auth/register/consumer` | POST | Public signup | 🔴 **HIGH** |
| `/api/auth/forgot-password` | POST | Password reset | Low |
| `/api/auth/reset-password` | POST | Password reset | Low |

### User Profile (2 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/user/profile` | PUT | Update user info | Medium |
| `/api/user/change-password` | POST | Change password | Medium |

### Admin (1 stub)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/admin/system/status` | GET | System health dashboard | Low |

### Manufacturer (3 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/manufacturer/device-types` | POST | Register new device type | Medium |
| `/api/manufacturer/device-types/{id}` | PUT | Update device type | Low |
| `/api/manufacturer/devices` | POST | Register device instance | Medium |

### Plant Catalog Admin (2 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/plant-type` | POST | Add species to catalog | Medium |
| `/api/plant-types/{id}` | PUT | Edit species | Low |

### Consumer Plants (3 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/consumer/plant-from-database` | POST | Add plant from catalog | 🔴 **HIGH** |
| `/api/consumer/plant-from-scratch` | POST | Add custom plant | 🔴 **HIGH** |
| `/api/consumer/my-plants/activation` | POST | Toggle plant care | Medium |
| `/api/consumer/my-plants/{id}` | PUT | Update plant details | Medium |

### Consumer Devices (2 stubs)

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/consumer/devices/register` | POST | Claim device by UID | 🔴 **HIGH** |
| `/api/consumer/my-devices/activation` | POST | Toggle device active | Medium |

### Monitoring & Alerts (5 stubs) - **ALL BLOCKING**

| Endpoint | Method | Frontend Usage | Priority |
|----------|--------|----------------|----------|
| `/api/consumer/devices/{id}/history` | GET | Sensor charts | 🔴 **HIGH** |
| `/api/consumer/devices/{id}/command` | POST | Manual control | 🔴 **HIGH** |
| `/api/consumer/alerts/{user_id}` | GET | Alert list | 🔴 **HIGH** |
| `/api/consumer/alerts/{id}/acknowledge` | PUT | Mark alert seen | Medium |
| `/api/consumer/alerts/{id}/resolve` | PUT | Dismiss alert | Medium |

---

## ❌ Missing Endpoints (Not defined in backend)

| Endpoint | Method | Frontend Usage | Notes |
|----------|--------|----------------|-------|
| `/api/manufacturer/devices` | POST | Register device instance | Frontend expects this but backend doesn't have it |

---

## URL Mismatches to Fix

| Frontend URL | Backend URL | Action Needed |
|--------------|-------------|---------------|
| `/plant-species/{id}` (PUT) | `/plant-types/{id}` | Update frontend or backend |
| `/plant-species/{id}` (DELETE) | `/plant-type/{id}` | Update frontend or backend |

---

## Implementation Priority

### 🔴 Phase 1 - Critical (Blocking Core Features)

1. `POST /api/auth/register/consumer` - Enable public signups
2. `POST /api/consumer/plant-from-database` - Add plants from catalog
3. `POST /api/consumer/plant-from-scratch` - Add custom plants
4. `POST /api/consumer/devices/register` - Claim devices

### 🟡 Phase 2 - High (Monitoring Features)

5. `GET /api/consumer/devices/{id}/history` - Sensor time-series data
6. `GET /api/consumer/alerts/{user_id}` - Alert notifications
7. `POST /api/consumer/devices/{id}/command` - Manual device control

### 🟢 Phase 3 - Medium (CRUD Completion)

8. `PUT /api/consumer/my-plants/{id}` - Update plants
9. `POST /api/consumer/my-plants/activation` - Toggle plant care
10. `POST /api/consumer/my-devices/activation` - Toggle devices
11. `PUT /api/user/profile` - Update profile
12. `POST /api/user/change-password` - Password change
13. `POST /api/manufacturer/devices` - Register device instances

### ⚪ Phase 4 - Low (Admin/Manufacturer Features)

14. `POST /api/auth/register` - Admin user creation
15. `POST /api/plant-type` - Add to plant catalog
16. `POST /api/manufacturer/device-types` - Register device types
17. Password reset flow endpoints
18. System status endpoint

---

## Notes for Backend Developer

- Frontend expects JSON responses matching schemas in `schemas.py`
- Time-series data for `/history` should support date range filtering (query params)
- Alert `severity` should be: `info`, `warning`, `critical`
- Alert `status` should be: `active`, `acknowledged`, `resolved`
- Consider pagination for large lists (add `skip`, `limit` query params)
- Frontend handles auth via `Bearer` token in `Authorization` header
- All endpoints return proper HTTP status codes (200, 201, 400, 401, 403, 404, 422, 500)
- **CORS is now enabled** for `localhost:3000`

---

*Report generated for Flutter frontend integration - November 28, 2025*