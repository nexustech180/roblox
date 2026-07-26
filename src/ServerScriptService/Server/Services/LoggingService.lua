--!strict
-- Thin, leveled wrapper around print/warn. Exists so every service logs the
-- same way and so a future swap to a real telemetry sink (e.g. an analytics
-- webhook) only touches one file.

local LoggingService = {}

function LoggingService.Info(message: string)
	print(`[INFO] {message}`)
end

function LoggingService.Warn(message: string)
	warn(`[WARN] {message}`)
end

function LoggingService.Error(message: string)
	warn(`[ERROR] {message}`)
end

function LoggingService.Init(_deps: any) end

return LoggingService
