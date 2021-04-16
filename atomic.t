local ffi = require "ffi"

local C = nil

if ffi.os == "Windows" then
C = terralib.includecstring [[
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <Windows.h>

#if defined(_AMD64_) || defined(_M_X64) || defined(_M_ARM64)

typedef long long atomic_t;
typedef unsigned long long unsigned_atomic_t;

atomic_t atomic_read(volatile atomic_t* value) {
    return InterlockedExchange64(value, *value);
}

atomic_t atomic_exchange(volatile atomic_t* value, atomic_t newvalue) {
    return InterlockedExchange64(value, newvalue);
}

atomic_t atomic_add(volatile atomic_t* value, atomic_t addvalue) {
    return _InlineInterlockedAdd64(value, addvalue);
}

atomic_t atomic_sub(volatile atomic_t* value, atomic_t subvalue) {
    return _InlineInterlockedAdd64(value, -subvalue);
}

#else

typedef long atomic_t;
typedef unsigned long unsigned_atomic_t;

long atomic_read(volatile long* value) {
    return _InlineInterlockedAdd(value, 0);
}

long atomic_add(volatile long* value, long addvalue) {
    return _InlineInterlockedAdd(value, addvalue);
}

long atomic_sub(volatile long* value, long subvalue) {
    return _InlineInterlockedAdd(value, -subvalue);
}

#endif
]]
else
C = terralib.includecstring [[
#if defined(_AMD64_) || defined(_M_X64) || defined(_M_ARM64)

typedef long long atomic_t;
typedef unsigned long long unsigned_atomic_t;

atomic_t atomic_read(volatile atomic_t* value) {
    return __sync_fetch_and_add(value, 0);
}

atomic_t atomic_add(volatile atomic_t* value, atomic_t addvalue) {
    return __sync_fetch_and_add(value, addvalue);
}

atomic_t atomic_sub(volatile atomic_t* value, atomic_t subvalue) {
    return __sync_fetch_and_add(value, -subvalue);
}

#else

typedef long atomic_t;
typedef unsigned long unsigned_atomic_t;

long atomic_read(volatile long* value) {
    return __sync_fetch_and_add(value, 0);
}

long atomic_add(volatile long* value, long addvalue) {
    return __sync_fetch_and_add(value, addvalue);
}

long atomic_sub(volatile long* value, long subvalue) {
    return __sync_fetch_and_add(value, -subvalue);
}

#endif
]]
end

local M = {}

local function issigned(type)
    return type == bool or type == int or type == int8 or type == int16 or type == int32 or type == int64
end

local function issupported(type)
    return issigned(type) or type == uint or type == uint8 or type == uint16 or type == uint32 or type == uint64
end

function M.Atomic(T)
    if not issupported(T) then
        error(("Type '%s' not supported for atomic values"):format(tostring(T)))
    end

    local AtomicType = C.unsigned_atomic_t
    if issigned(T) then
        AtomicType = C.atomic_t
    end

    local struct Atomic {
        value: AtomicType
    }

    terra Atomic:fetch(): T
        return [T](C.atomic_read(&self.value))
    end
    terra Atomic:fetchexchange(value: T): T
        return [T](C.atomic_exchange(&self.value, [AtomicType](value)))
    end

    if T ~= bool then
        terra Atomic:fetchadd(addvalue: T): T
            return [T](C.atomic_add(&self.value, [AtomicType](addvalue)))
        end
        terra Atomic:fetchsub(subvalue: T): T
            return [T](C.atomic_sub(&self.value, [AtomicType](subvalue)))
        end
    end

    return Atomic
end
M.Atomic = terralib.memoize(M.Atomic)

M.makeatomic = macro(function(v)
    return quote
        var a: M.Atomic(v:gettype())
        a:fetchexchange(v)
    in
        a
    end
end)

M.AtomicBool = M.Atomic(bool)
M.AtomicInt = M.Atomic(int)
--M.AtomicUint = M.Atomic(uint)

return M