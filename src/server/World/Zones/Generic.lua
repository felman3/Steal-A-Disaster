--[[
	Generic fallback zone builder: used only when a zone has no dedicated
	builder in World/Zones/<ZoneId>.lua. Gives each zone a distinct ground
	material/color and simple props so the route is always playable.
]]

local PALETTES = {
	Overgrowth = { ground = { 70, 120, 50 }, mat = Enum.Material.LeafyGrass, prop = { 150, 90, 160 }, accent = { 170, 255, 110 } },
	Droughtlands = { ground = { 205, 160, 105 }, mat = Enum.Material.Sandstone, prop = { 170, 110, 70 }, accent = { 255, 200, 90 } },
	Frostfall = { ground = { 235, 242, 255 }, mat = Enum.Material.Snow, prop = { 150, 210, 255 }, accent = { 170, 230, 255 } },
	MagmaBasin = { ground = { 50, 40, 40 }, mat = Enum.Material.Basalt, prop = { 255, 90, 20 }, accent = { 255, 120, 40 } },
	DeepAbyss = { ground = { 30, 50, 80 }, mat = Enum.Material.Sand, prop = { 60, 220, 200 }, accent = { 80, 230, 255 } },
	Prehistoric = { ground = { 110, 120, 60 }, mat = Enum.Material.Ground, prop = { 230, 220, 190 }, accent = { 255, 180, 70 } },
	Skylands = { ground = { 230, 235, 255 }, mat = Enum.Material.SmoothPlastic, prop = { 255, 255, 255 }, accent = { 170, 210, 255 } },
	VoidRealm = { ground = { 20, 10, 30 }, mat = Enum.Material.Glass, prop = { 160, 60, 255 }, accent = { 200, 100, 255 } },
}

return function(ctx)
	local Kit = ctx.Kit
	local pal = PALETTES[ctx.zone.id] or { ground = { 120, 120, 120 }, mat = Enum.Material.Slate, prop = { 200, 200, 200 }, accent = { 255, 255, 255 } }
	local zm = (ctx.z0 + ctx.z1) / 2
	Kit.part(ctx.folder, { name = "Ground", size = Vector3.new(ctx.width, 4, ctx.length), cf = CFrame.new(0, -2, zm), color = pal.ground, material = pal.mat })
	Kit.part(ctx.folder, { name = "Path", size = Vector3.new(ctx.pathWidth, 0.3, ctx.length * 0.55), cf = CFrame.new(0, 0.15, ctx.z0 + ctx.length * 0.275), color = Kit.shade(pal.ground, 0.8), material = pal.mat })
	for i = 1, 26 do
		local side = (i % 2 == 0) and 1 or -1
		local x = side * ctx.rng(ctx.pathWidth / 2 + 8, ctx.width / 2 - 6)
		local z = ctx.rng(ctx.z0 + 8, ctx.z1 - 8)
		if (Vector3.new(x, 0, z) - ctx.nest).Magnitude > ctx.nestRadius + 14 then
			local h = ctx.rng(3, 12)
			Kit.part(ctx.folder, { name = "Prop", size = Vector3.new(ctx.rng(3, 8), h, ctx.rng(3, 8)), cf = CFrame.new(x, h / 2, z) * CFrame.Angles(0, ctx.rng(0, 3), 0), color = pal.prop, material = pal.mat })
		end
	end
	return { palette = { accent = pal.accent, gate = Kit.shade(pal.ground, 0.6), nest = Kit.shade(pal.ground, 0.7) } }
end
