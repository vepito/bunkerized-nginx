local M		= {}
local api_list	= {}
local iputils	= require "resty.iputils"

api_list["^/ping$"] = function ()
	return true
end

api_list["^/reload$"] = function ()
	local jobs = true
	local file = io.open("/etc/nginx/global.env", "r")
	for line in file:lines() do
		if line == "KUBERNETES_MODE=yes" or line == "SWARM_MODE=yes" then
			jobs = false
			break
		end
	end
	file:close()
	if jobs then
		os.execute("/opt/bunkerized-nginx/entrypoint/jobs.sh")
	end
	return os.execute("/usr/sbin/nginx -s reload") == 0
end

api_list["^/stop$"] = function ()
	return os.execute("/usr/sbin/nginx -s quit") == 0
end

function M.is_api_call (api_uri, api_whitelist_ip)
	local whitelist = iputils.parse_cidrs(api_whitelist_ip)
	if iputils.ip_in_cidrs(ngx.var.remote_addr, whitelist) and ngx.var.request_uri:sub(1, #api_uri) .. "/" == api_uri .. "/" then
		for uri, code in pairs(api_list) do
			if string.match(ngx.var.request_uri:sub(#api_uri + 1), uri) then
				return true
			end
		end
	end
	return false
end

function M.do_api_call (api_uri)
	for uri, code in pairs(api_list) do
		if string.match(ngx.var.request_uri:sub(#api_uri + 1), uri) then
			return code()
		end
	end
end

return M
