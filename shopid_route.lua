local redis_funs = require "kong.core.redis_funs"
local _M = {}

function _M.CheckShopId(shopid,host)
    if redis_funs.IsInGroupIds(host, shopid) then
        local new_host = redis_funs.GetHost('hll_route_pay', 'kong_'..host)
        if ( new_host ~= nil ) then
            ngx.req.set_header('Host', new_host)
            ngx.log(ngx.ERR, "mspay_host:"..new_host)
            return true
        end
    end
    return false
end
return _M
