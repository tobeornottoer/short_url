--短链接服务

local mysql  = require "resty.mysql"
local db,err = mysql:new()
if not db then
	ngx.say("failed to instantiate mysql: ", err)
	return
end

db:set_timeout(1000) -- 1 sec

local ok, err, errcode, sqlstate = db:connect{
	host = "127.0.0.1",
	port = 3306,
	database = "short_url",
	user = "root",
	password = "123456",
	charset = "utf8",
	max_packet_size = 1024 * 1024,
}

if not ok then
	ngx.say("failed to connect: ", err, ": ", errcode, " ", sqlstate)
	return
end

function getKey()
	local key = ''
	local ele = {'1','2','3','4','5','6','7','8','9','0','a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z','A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','S','X','Y','Z'}
	math.random(tostring(ngx.now()):reverse():sub(1, 6))
	for i=1, 8 do
		key = key..ele[math.random(1,62)]
	end
	return key
end

function createUrl()
	for i=1,100 do
		local sql = "INSERT INTO short (`key`,`url`) VALUES "
		local key = ""
		local res, err, errcode, sqlstate
		for v=1,100 do
			key = getKey()
			if v == 100 then
				sql = sql.."('"..key.."','http://short_url.com/real/url/"..key.."')"
			else
				sql = sql.."('"..key.."','http://short_url.com/real/url/"..key.."'),"
			end
		end
		res, err, errcode, sqlstate =
		db:query(sql)
		if not res then
			ngx.say("bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
			return
		end
	end
end

function getRealUrl(db,key)
	local sql = "SELECT url,expire FROM short WHERE `key` = '"..key.."'"
	local res,err,errcode,sqlstate = db:query(sql)
	if not res then
		ngx.say('bad result:',err,':',errcode,":",sqlstate,".")
		return
	end
	if res[1] == nil or next(res) == nil then
		ngx.say('no value')
	elseif res[1].expire ~=0 and res[1].expire < ngx.time() then
		ngx.say('expire')
	else
		db:set_keepalive(10000,10) --将连接放入连接池
		ngx.redirect(res[1]['url'],302) -- 这条语句执行后，往下的lua代码将不会被执行
	end
	return
end

function addUrl(params,db)
	if params == nil or params['url'] == nil or params['url'] == ngx.null then
		ngx.say("url Cannot be empty")
	else
		local url = params["url"]
		local key = getKey()
		local sql = "INSERT INTO short (`key`,`url`) VALUES ('"..key.."','"..url.."')"
		local res, err, errcode, sqlstate
		res, err, errcode, sqlstate = db:query(sql)
		if not res then
			ngx.say("bad result: ", err, ": ", errcode, ": ", sqlstate, ".")
			return
		end
		ngx.say(key)
	end
	return
end



local key = string.sub(ngx.var.uri,2)

if key == 'manager' and ngx.req.get_method() == 'GET' then
	return ngx.redirect("/manager.html")
elseif key == 'manager' and ngx.req.get_method() == 'POST' then
	ngx.req.read_body()
	local params = ngx.req.get_post_args()
	addUrl(params,db)
else
	getRealUrl(db,key)
end

db:set_keepalive(10000,10) --将连接放入连接池


