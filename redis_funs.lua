local redis = require "kong.core.redis_iresty"
local _M = {}
_M._VERSION = '1.0'
function _M.IsInGroupIds(set, value)
    local red = redis:new()
    local res, err = red:sismember(set, value)
    if res == 1 then
        ngx.log(ngx.ERR, "redis_search:"..res)
        return true
    else
        --ngx.log(ngx.ERR, "redis_search:"..res)
        return false
    end
end

function _M.GetHost(key)
    local red = redis:new()
    --redis hashtable
    local res, err = red:hmget('myhash',key)
    if (res ~= nil) then
        ngx.log(ngx.ERR, "redis_search:"..res[1])
        return res[1]
    else
        ngx.log(ngx.ERR, "redis_search:"..err)
        return nil
    end
end
return _M
