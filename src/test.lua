local http = require("httplib/socket/http")
local ltn12 = require("httplib/ltn12")

-- The Request Bin test URL: http://requestb.in/12j0kaq1
function sendRequest()
local path = "http://requestb.in/12j0kaq1?param_1=one&param_2=two&param_3=three"
  local payload = [[ {"key":"My Key","name":"My Name","description":"The description","state":1} ]]
  local response_body = { }

  local res, code, response_headers, status = http.request
  {
    url = path,
    method = "POST",
    headers =
    {
      ["Authorization"] = "Maybe you need an Authorization header?",
      ["Content-Type"] = "application/json",
      ["Content-Length"] = payload:len()
    },
    source = ltn12.source.string(payload),
    sink = ltn12.sink.table(response_body)
  }
  luup.task('Response: = ' .. table.concat(response_body) .. ' code = ' .. code .. '   status = ' .. status,1,'Sample POST request with JSON data',-1)
end