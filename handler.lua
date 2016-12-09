-- Kong core
--
-- This consists of events that need to
-- be ran at the very beginning and very end of the lua-nginx-module contexts.
-- It mainly carries information related to a request from one context to the next one,
-- through the `ngx.ctx` table.
--
-- In the `access_by_lua` phase, it is responsible for retrieving the API being proxied by
-- a Consumer. Then it is responsible for loading the plugins to execute on this request.
local utils = require "kong.tools.utils"
local reports = require "kong.core.reports"
local cluster = require "kong.core.cluster"
local resolver = require "kong.core.resolver"
local constants = require "kong.constants"
local certificate = require "kong.core.certificate"
local groupid_route = require "kong.core.groupid_route"
local shopid_route = require "kong.core.shopid_route"
local redis_funs = require "kong.core.redis_funs"
local hll_route_conf = require "kong.core.hll_route_conf"
local ngx_now = ngx.now
local server_header = _KONG._NAME.."/".._KONG._VERSION

local function get_now()
  return ngx_now() * 1000 -- time is kept in seconds with millisecond resolution.
end

-- in the table below the `before` and `after` is to indicate when they run; before or after the plugins
return {
  init_worker = {
    before = function()
      reports.init_worker()
      cluster.init_worker()
    end
  },
  certificate = {
    before = function()
      ngx.ctx.api = certificate.execute()
    end
  },
  access = {
    before = function()
      ngx.ctx.KONG_ACCESS_START = get_now()
      local header_group_id = tonumber(ngx.req.get_headers()["groupID"])
      local header_shop_id = tonumber(ngx.req.get_headers()["shopID"])
      local header_host = ngx.req.get_headers()["Host"]
      pay_status=false
      --pan duan shi fou shi zhutaima
      if (header_host == hll_route_conf.ztm_host) then
	      local uri_args = ngx.req.get_uri_args()
		  if uri_args['s'] then
              header_group_id = redis_funs.GetValue('hll_route_ztm', uri_args['s'])
		      --ngx.log(ngx.ERR, "uri_args['s']:"..uri_args['s'])
			  if (header_group_id == nil) then
                  local set_status = redis_funs.SetValue('hll_ztm_misgroupid', uri_args['s'])
              end
         end
      end
      --route by shopID or groupID
      if (header_shop_id ~= nil) and (header_host ~= nil) then
		  --ngx.log(ngx.ERR, "header_shop_id:"..header_shop_id)
          pay_status = shopid_route.CheckShopId(header_shop_id,header_host)
      elseif (header_group_id ~= nil) and (header_host ~= nil) then
          groupid_route.CheckGroupId(header_group_id,header_host)
      end
      ngx.ctx.api, ngx.ctx.upstream_url, ngx.var.upstream_host = resolver.execute(ngx.var.request_uri, ngx.req.get_headers())
    end,
    -- Only executed if the `resolver` module found an API and allows nginx to proxy it.
    after = function()
      -- Append any querystring parameters modified during plugins execution
      local upstream_url = ngx.ctx.upstream_url
      local uri_args = ngx.req.get_uri_args()
      ngx.log(ngx.ERR, "upstream_url_before:"..upstream_url)
      if pay_status then
          local match, err = ngx.re.match(ngx.ctx.upstream_url, hll_route_conf.pay_filter, "o")
          if (match ~= nil) then
		      upstream_url = ngx.re.sub(upstream_url, "/WxPay/", "/newWxPay/", "o")
	      end 
		 ngx.log(ngx.ERR, "upstream_url_pay:"..upstream_url)
      end
      if next(uri_args) then
        upstream_url = upstream_url.."?"..utils.encode_args(uri_args)  
	    ngx.log(ngx.ERR, "upstream_url_after:"..upstream_url) 
      end

      -- Set the `$upstream_url` and `$upstream_host` variables for the `proxy_pass` nginx
      -- directive in kong.yml.
      ngx.var.upstream_url = upstream_url

      local now = get_now()
      ngx.ctx.KONG_ACCESS_TIME = now - ngx.ctx.KONG_ACCESS_START -- time spent in Kong's access_by_lua
      ngx.ctx.KONG_ACCESS_ENDED_AT = now
      -- time spent in Kong before sending the reqeust to upstream
      ngx.ctx.KONG_PROXY_LATENCY = now - ngx.req.start_time() * 1000 -- ngx.req.start_time() is kept in seconds with millisecond resolution.
      ngx.ctx.KONG_PROXIED = true
    end
  },
  header_filter = {
    before = function()
      if ngx.ctx.KONG_PROXIED then
        local now = get_now()
        ngx.ctx.KONG_WAITING_TIME = now - ngx.ctx.KONG_ACCESS_ENDED_AT -- time spent waiting for a response from upstream
        ngx.ctx.KONG_HEADER_FILTER_STARTED_AT = now
      end
    end,
    after = function()
      if ngx.ctx.KONG_PROXIED then
        ngx.header[constants.HEADERS.UPSTREAM_LATENCY] = ngx.ctx.KONG_WAITING_TIME
        ngx.header[constants.HEADERS.PROXY_LATENCY] = ngx.ctx.KONG_PROXY_LATENCY
        ngx.header["Via"] = server_header
      else
        ngx.header["Server"] = server_header
      end
    end
  },
  body_filter = {
    after = function()
      if ngx.arg[2] and ngx.ctx.KONG_PROXIED then
        -- time spent receiving the response (header_filter + body_filter)
        -- we could uyse $upstream_response_time but we need to distinguish the waiting time
        -- from the receiving time in our logging plugins (especially ALF serializer).
        ngx.ctx.KONG_RECEIVE_TIME = get_now() - ngx.ctx.KONG_HEADER_FILTER_STARTED_AT
      end
    end
  },
  log = {
    after = function()
      reports.log()
    end
  }
}
