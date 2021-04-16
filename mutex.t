local C = terralib.includecstring [[
#include <pthread.h>
]]

local E = require 'terrasync.error'

local M = {}

local struct Mutex {
    pm: C.pthread_mutex_t
}

terra Mutex:destroy()
    C.pthread_mutex_destroy(&self.pm)
end

terra Mutex:init(): E.Error
    return E.Error{ C.pthread_mutex_init(&self.pm, nil) }
end

terra Mutex:lock()
    C.pthread_mutex_lock(&self.pm)
end

terra Mutex:unlock()
    C.pthread_mutex_unlock(&self.pm)
end

terra M.makemutex(): {Mutex, E.Error}
    var m: Mutex
    var err = m:init()
    return m, err
end

M.withlock = function(mutex, body)
    return quote
        mutex:lock()
        body
        mutex:unlock()
    end
end

M.Mutex = Mutex
return M