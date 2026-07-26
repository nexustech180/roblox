--!strict
-- Thin wrapper around the Notify remote so every service sends toasts the
-- same shape instead of hand-rolling FireClient calls everywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = require(ReplicatedStorage.Shared.Remotes.Remotes)

export type ToastKind = "info" | "success" | "warning" | "danger"

local NotifyService = {}

function NotifyService.Toast(player: Player, text: string, kind: ToastKind?)
	Remotes.Notify:FireClient(player, { text = text, kind = kind or "info" })
end

function NotifyService.ToastAll(text: string, kind: ToastKind?)
	Remotes.Notify:FireAllClients({ text = text, kind = kind or "info" })
end

function NotifyService.ToastMany(players: { Player }, text: string, kind: ToastKind?)
	for _, player in ipairs(players) do
		NotifyService.Toast(player, text, kind)
	end
end

function NotifyService.Init(_deps: any) end

return NotifyService
