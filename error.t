local C = terralib.includecstring [[
#include <string.h>
]]

local M = {}

local struct Error {
    code: int
}

terra Error:iserror(): bool
    return self.code ~= 0
end

terra Error:getstring(): rawstring
    return C.strerror(self.code)
end

M.Error = Error
return M