local redis_funs = require "kong.core.redis_funs"
local _M = {}
_M._VERSION = '1.0'
function _M.CheckGroupId(groupid)
    if ( groupid ~= nil ) then
        if redis_funs.IsInGroupIds('hll_vip_groupids', groupid) then
            local vip_host = redis_funs.GetHost('vip_groupid_host')
                if ( vip_host == nil ) then
                    vip_host = ''
                end
            --ngx.log(ngx.ERR, "vip_host:"..vip_host)
            ngx.req.set_header('Host', vip_host)
            ngx.log(ngx.ERR, "Host-vip:"..ngx.req.get_headers()["Host"])
        elseif redis_funs.IsInGroupIds('hll_smallflow_groupids', groupid) then
            local smallflow_host = redis_funs.GetHost('smallflow_groupid_host')
            if ( smallflow_host == nil ) then
                smallflow_host = ''
            end
            ngx.req.set_header('Host', smallflow_host)
            ngx.log(ngx.ERR, "Host-smallflow:"..ngx.req.get_headers()["Host"])
        end
    end
end
return _M
