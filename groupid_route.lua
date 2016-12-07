local redis_funs = require "kong.core.redis_funs"
local _M = {}

function _M.CheckGroupId(groupid,host)
    if redis_funs.IsInGroupIds(host, groupid) then
        local new_host = redis_funs.GetHost('hll_route_vip', 'kong_'..host)
        if ( new_host ~= nil ) then
            ngx.req.set_header('Host', new_host)
            ngx.log(ngx.ERR, "vip_host:"..new_host)
        end
    end
end
return _M
