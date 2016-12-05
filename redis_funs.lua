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

function _M.GetHost(field)
    local red = redis:new()
    --redis hashtable,from hll_route_vip
    --ngx.log(ngx.ERR, "redis_field:"..field)
        local res, err = red:hget('hll_route_vip',field)
    if (res ~= nil) then
        ngx.log(ngx.ERR, "redis_search:"..res)
        return res
    else
        return nil
    end
end
return _M
