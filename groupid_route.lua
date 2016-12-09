--[[
   author: dangersheng@hualala.com
   date: 2016/12/09
   version: 1.0
--]]

local redis_funs = require "kong.core.redis_funs"
local hll_route_conf = require "kong.core.hll_route_conf"
local _M = {}

function _M.CheckGroupId(groupid,host)
	if redis_funs.IsInGroupIds(host, groupid) then
		local new_host = redis_funs.GetValue(hll_route_conf.route_vip, 'kong_'..host)
		if ( new_host ~= nil ) then
			ngx.req.set_header('Host', new_host)
			ngx.log(ngx.ERR, "vip_host:"..new_host)
		end
	end
end
return _M
