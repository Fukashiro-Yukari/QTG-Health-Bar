AddCSLuaFile()

local netr = {}
local function startnet(a,b,t,v,...)
    net.Start(a)
    net.WriteString(b)
    net.WriteTable({...})

    if SERVER then
        t = t or 'Broadcast'

        if net[t] then
            net[t](v)

            return true
        else
            return false
        end
    else
        net.SendToServer()

        return true
    end

    return false
end

local function snet(a,...)
    return startnet('qhpbar_getnpc',a,nil,nil,...)
end

local function readnet(a,b,c)
    net.Receive(a,function(_,p)
        local id = net.ReadString()
        local t = net.ReadTable()
    
        if netr[id] then
            netr[id](unpack(t))
        end
    end)

    netr[b] = c
end

if CLIENT then

QTGHPBar = {}

local cinfo = {}
function QTGHPBar.Addinfo(a,b)
    if !b then
        b = a
        a = ''

        for i=0,12 do
            local r = math.random(97,122)
            a = a..string.char(r)
        end
    end
    
    cinfo[a] = b
end

local function addhook(a,b,c)
    hook.Add(a,c or 'qtg_hpbar',b)
end

local function addfont(a,b)
	surface.CreateFont(a,{font = 'Roboto Bk',size = b,weight = 600})
end
addfont('qtg_hpntext',30)
addfont('qtg_hpntext2',20)

local function addconvar(a,b,c)
    return CreateClientConVar('qtg_hpbar_'..a,b,true,false,c)
end

local function getconvar(a)
    return GetConVar('qtg_hpbar_'..a)
end

local on = addconvar('on',1,'Enable or disable')
local bossbar = addconvar('bossbar',1,'Enable or disable boss bar')
local mode3d = addconvar('3d',0,'Enable 3D')
local showall = addconvar('showall',0,'Show all entities directly')
local colr = addconvar('r',0,'red')
local colg = addconvar('g',0,'greed')
local colb = addconvar('b',0,'blue')
local cola = addconvar('a',200,'alpha')
local distance = addconvar('distance',5000,'Visible distance')
local isboss = addconvar('isboss',1500,'How much health will become a boss')
local entboss = addconvar('entboss',0,'Entities will become bosses')

local function getheadpos(e)
	if !IsValid(e) then return end
	
    local model = e:GetModel() or ''
	
    if model:find('crow') or model:find('seagull') or model:find('pigeon') then
        return e:LocalToWorld(e:OBBCenter()+Vector(0,0,-5))
    elseif e:GetAttachment(e:LookupAttachment('eyes')) then
        return e:GetAttachment(e:LookupAttachment('eyes')).Pos
    else
        return e:LocalToWorld(e:OBBCenter())
    end
end

local fontn = 'qtg_hpntext'
local function drawText(s,f,x,y,c,t,a,b)
    if !istable(t) then
        b = a
        a = t
    else
        t[#t+1] = s or ''
    end

    if x < -1e5 or y < -1e5 then return end

    draw.DrawText(s,f,x+3,y+3,Color(0,0,0,c.a-55),a,b)
    draw.DrawText(s,f,x,y,c,a,b)
end

local function gettext(e)
    if !IsValid(e) then return '' end
    if language.GetPhrase(e:GetClass()) == e:GetClass() then
        if e.PrintName then
            return e.PrintName
        elseif e:IsPlayer() then
            return e:Name()
        end
    else
        return language.GetPhrase(e:GetClass())
    end

    return ''
end

local function gettextsize(a,...)
    local max = -1e9
    local args

    surface.SetFont('qtg_hpntext')

    if istable(a) then
        args = a
    else
        args = {a,...}
    end

    for k,v in pairs(args) do
        v = !isnumber(v) and (surface.GetTextSize(v) or 0) or v

        if v > max then
            max = v
        end
    end

    return max
end

local function numr(a,b)
    return math.max(b-a,0)
end

local function getnamecolor(e,a)
    local cd = Color(255,255,255,a)
    local cg = Color(150,255,150,a)
    local cb = Color(255,150,150,a)
    local p = LocalPlayer()

    if e:IsPlayer() then
        local color = team.GetColor(e:Team())
        color.a = a

        return color
    elseif e:IsNPC() then
        snet('getdisp',p,e)
        
        local disp = e:GetNW2Int('qhpbar_getnpcd')
        if disp > 0 then
            if disp == 2 or disp == 1 then
                return cb
            else
                return cg
            end
        end
    end

    return cd
end

local function gethealthcolor(e,a)
    local hd = Color(255,255,255,a)
    local hg = Color(150,255,150,a)
    local hb = Color(255,150,150,a)

    if e:Health()/e:GetMaxHealth() < 0.25 then
        return hb
    end

    return hd
end

local npcst = {
    [-1] = 'Invalid',
    [0] = 'Default',
    [1] = 'Idle',
    [2] = 'Alert',
    [3] = 'Combat',
    [4] = 'Script',
    [5] = 'Playing dead',
    [6] = 'Prone to death',
    [7] = 'Dead'
}

local function getnpcstate(e)
    snet('getstate',e)

    return e:GetNW2Int('qhpbar_getnpcs')
end

local function drawtext(v,fontc,x,y)
    local n = 0
    local args = {}
    x = x or -1e9
    y = y or -1e9

    local function dtext(a,b)
        y = y-30
        n = n+1

        if b == true then
            b = getnamecolor(v,fontc.a)
        end

        drawText(a,fontn,x,y,b or fontc,args,TEXT_ALIGN_CENTER)
    end

    hook.Run('QTG_OnHealthBarDrawText')

    for k,f in pairs(cinfo) do
        local fr = f(v)
        if fr then
            dtext(fr)
        end
    end
    
    local w = v.GetActiveWeapon and v:GetActiveWeapon() or nil
    if IsValid(w) then
        dtext(w:GetClass())

        if gettext(w) != '' then
            dtext(gettext(w))
        end
    end

    if IsValid(v:GetOwner()) then
        if v:GetOwner() == v then
            dtext('Owner: He himself')
        elseif v:GetOwner():IsPlayer() then
            dtext('Owner: '..v:GetOwner():Name())
        else
            dtext('Owner: '..gettext(v:GetOwner()))
        end
    end

    dtext('Type: '..type(v))

    if v:IsNPC() then
        dtext(npcst[getnpcstate(v)],true)
    elseif v:IsPlayer() then
        dtext(team.GetName(v:Team()),true)
    end

    dtext(v:GetClass(),true)

    if gettext(v) != '' then
        dtext(gettext(v),true)
    end

    return n,gettextsize(v:Health()..' / '..v:GetMaxHealth(),unpack(args))
end

local health
local function drawhud(v,x,y)
    if !GetConVar('cl_drawhud'):GetBool() then return end
    if !on:GetBool() then return end

    surface.SetFont(fontn)

    local p = LocalPlayer()
    local dist = Lerp(numr(v:GetPos():Distance(p:GetPos()),distance:GetInt())/1000,-55,cola:GetInt())
    local fontc = Color(255,255,255,dist+55)
    local li,fx = drawtext(v,fontc)
    
    if !mode3d:GetBool() then
        x,y = math.Clamp(x,100,ScrW()-(fx+100)),math.Clamp(y,200,ScrH()-150)
    end

    y = y-100

    surface.SetDrawColor(colr:GetInt(),colg:GetInt(),colb:GetInt(),dist)

    if v:GetParent() != p then
        surface.DrawRect(x-10,y-(2+30*li),fx+20,35+30*li)
    end

    if v:Health() != 0 and v:GetMaxHealth() != 0 then
        local hp = v:Health()

        if v:IsPlayer() then
            hp = v:Alive() and hp or 0
        elseif v:IsNPC() then
            hp = getnpcstate(v) != 7 and hp or 0
        end

        health = Lerp(math.Clamp(FrameTime()*5,0,1),health or fx+10,math.min(v:Health(),v:GetMaxHealth())*((fx+11)/v:GetMaxHealth()))

        surface.SetDrawColor(0,0,0,dist)
        surface.DrawRect(x-5,y+2,fx+10,28)
        surface.SetDrawColor(255,0,0,dist)
        surface.DrawRect(x-5,y+2,health,28)
        drawText(hp..' / '..v:GetMaxHealth(),fontn,x+(fx/2),y,gethealthcolor(v,fontc.a),TEXT_ALIGN_CENTER)
    end

    x = x+(fx/2)
    
    if v:GetParent() != p then
        drawtext(v,fontc,x,y)
    end
end

local bosstbl = {}
local fontn = 'qtg_hpntext2'
local health2 = {}
local function drawhud2()
    if !GetConVar('cl_drawhud'):GetBool() then return end
    if !on:GetBool() then return end
    if !bossbar:GetBool() then return end

    local x,y,w,h = ScrW()/2,10,800,50
    local n = 0

    for k,v in pairs(ents.GetAll()) do
        if v != p and v:Health() >= isboss:GetFloat() then
            if !entboss:GetBool() and !v:IsNPC() and !v:IsPlayer() and type(v) != 'Nextbot' then
            else
                bosstbl[v] = bosstbl[v] or {e = v}
            end
        end
    end

    for k,v in pairs(bosstbl) do
        if n >= 4 then
            break
        end

        local t = v
        v = v.e

        if IsValid(v) then
            if v:IsPlayer() and !v:Alive() then
                bosstbl[v] = nil
            elseif v:IsNPC() and getnpcstate(v) == 7 then
                bosstbl[v] = nil
            end

            surface.SetDrawColor(colr:GetInt(),colg:GetInt(),colb:GetInt(),cola:GetInt())
            surface.DrawRect(x-(w/2),y,w,h)

            local name
            if v:IsPlayer() then
                name = v:Name()
            elseif gettext(v) != '' then
                name = gettext(v)
            else
                name = v:GetClass()
            end

            local hp = v:Health()
            if v:IsPlayer() then
                hp = v:Alive() and hp or 0
            elseif v:IsNPC() then
                hp = getnpcstate(v) != 7 and hp or 0
            end

            local maxhp
            if t.maxhp and hp <= t.maxhp then
                maxhp = t.maxhp
            else
                maxhp = math.max(v:GetMaxHealth(),1000)

                if hp > maxhp then
                    maxhp = hp
                    bosstbl[v].maxhp = maxhp
                end
            end

            health2[v] = Lerp(math.Clamp(FrameTime()*5,0,1),health2[v] or w-8,math.min(hp,maxhp)*((w-8)/maxhp))

            drawText('Boss: '..name,fontn,x,y,Color(255,255,255,255),TEXT_ALIGN_CENTER)
            surface.SetDrawColor(0,0,0,200)
            surface.DrawRect(x-(w/2)+4,y+h/2-4,w-8,h/2)
            surface.SetDrawColor(255,0,0,255)
            surface.DrawRect(x-(w/2)+4,y+h/2-4,health2[v],h/2)
            drawText(hp..' / '..v:GetMaxHealth(),fontn,x,y+25,Color(255,255,255,255),TEXT_ALIGN_CENTER)

            y = y+h
            n = n+1
        else
            bosstbl[v] = nil
        end
    end
end

addhook('HUDPaint',function()
    drawhud2()

    if mode3d:GetBool() then return end

    local p = LocalPlayer()

    local function start(e)
        if !IsValid(e) then return end

        local hpos = getheadpos(e) or e:GetPos()
        local pos = hpos:ToScreen()

        if pos then
            drawhud(e,pos.x+50,pos.y+100)
        end
    end

    if showall:GetBool() then
        for k,v in pairs(ents.GetAll()) do
            if v != p then
                start(v)
            end
        end
    else
        start(p:GetEyeTrace().Entity)
    end
end)

addhook('PostDrawOpaqueRenderables',function(a,b)
    if !mode3d:GetBool() then return end

    local p = LocalPlayer()

    local function start(e)
        if !IsValid(e) then return end

        local pos = getheadpos(e) or e:GetPos()
        local ang = p:GetAngles()
        local fixr = Vector(0,-90,90)
        pos = pos + ang:Right()*9
        ang.p = 0
        ang:RotateAroundAxis(ang:Right(),fixr.x)
        ang:RotateAroundAxis(ang:Up(),fixr.y)
        ang:RotateAroundAxis(ang:Forward(),fixr.z)

        cam.Start3D2D(pos,ang,0.1)
            drawhud(e,50,100)
        cam.End3D2D()
    end

    if showall:GetBool() then
        for k,v in pairs(ents.GetAll()) do
            if v != p then
                start(v)
            end
        end
    else
        start(p:GetEyeTrace().Entity)
    end
end)

else

local netname = 'qhpbar_getnpc'
util.AddNetworkString(netname)

readnet(netname,'getdisp',function(p,e)
    if IsValid(p) and IsValid(e) and e:IsNPC() then
        e:SetNW2Int('qhpbar_getnpcd',e:Disposition(p))
    end
end)

readnet(netname,'getstate',function(e)
    if IsValid(e) and e:IsNPC() then
        e:SetNW2Int('qhpbar_getnpcs',e:GetNPCState())
    end
end)

end