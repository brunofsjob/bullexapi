-- Support Resistance Channels (Verso Simplificada)
-- Baseado no original de LonesomeTheBlue
-- Apenas canais S/R com configurao padro

instrument { 
    name = "Support Resistance Channels", 
    short_name = "SRchannel",
    overlay = true 
}

-- Configuraes fixas (conforme sua imagem)
local prd = 10                  -- Pivot Period
local ppsrc = "High/Low"        -- Fonte
local ChannelW = 5              -- Maximum Channel Width %
local minstrength = 1           -- Minimum Strength
local maxnumsr = 6 - 1           -- Maximum Number of S/R (subtrai 1 como no original)
local loopback = 290            -- Loopback Period

-- Cores fixas (equivalentes ao original com transparncia)
local res_col = "#FF0000"        -- Vermelho para resistncia
local sup_col = "#00FF00"        -- Verde para suporte
local inch_col = "#808080"       -- Cinza quando preo est no canal

-- Fonte para pivots
local src1 = high
local src2 = low

-- Funo Pivot High
local function pivothigh(source, leftbars, rightbars)
    if current_index < leftbars + rightbars then
        return nil
    end
    local pivot_value = source[rightbars]
    local is_pivot = true
    for i = 1, leftbars do
        if source[rightbars + i] >= pivot_value then
            is_pivot = false
            break
        end
    end
    if is_pivot then
        for i = 1, rightbars do
            if source[i] and source[i] >= pivot_value then
                is_pivot = false
                break
            end
        end
    end
    return is_pivot and pivot_value or nil
end

-- Funo Pivot Low
local function pivotlow(source, leftbars, rightbars)
    if current_index < leftbars + rightbars then
        return nil
    end
    local pivot_value = source[rightbars]
    local is_pivot = true
    for i = 1, leftbars do
        if source[rightbars + i] <= pivot_value then
            is_pivot = false
            break
        end
    end
    if is_pivot then
        for i = 1, rightbars do
            if source[i] and source[i] <= pivot_value then
                is_pivot = false
                break
            end
        end
    end
    return is_pivot and pivot_value or nil
end

-- Calcular pivots
local ph = pivothigh(src1, prd, prd)
local pl = pivotlow(src2, prd, prd)

-- Largura mxima do canal
local prdhighest = highest(high, 300)
local prdlowest = lowest(low, 300)
local cwidth = (prdhighest - prdlowest) * ChannelW / 100

-- Armazenar pivots (persistentes)
if not pivotvals then
    pivotvals = {}
    pivotlocs = {}
end

-- Adicionar novo pivot e remover antigos
if ph or pl then
    table.insert(pivotvals, 1, ph or pl)
    table.insert(pivotlocs, 1, current_index)
    
    -- Remover pivots fora do loopback (remove do final)
    while #pivotlocs > 0 and current_index - pivotlocs[#pivotlocs] > loopback do
        table.remove(pivotlocs)
        table.remove(pivotvals)
    end
end

-- Funo para agrupar pivots em canal
local function get_sr_vals(ind)
    if ind > #pivotvals then return nil, nil, 0 end
    local lo = pivotvals[ind]
    local hi = lo
    local numpp = 0
    for y = 1, #pivotvals do
        local cpp = pivotvals[y]
        local wdth = cpp <= hi and (hi - cpp) or (cpp - lo)
        if wdth <= cwidth then
            if cpp <= hi then
                lo = math.min(lo, cpp)
            else
                hi = math.max(hi, cpp)
            end
            numpp = numpp + 20
        end
    end
    return hi, lo, numpp
end

-- Array para canais S/R
if not suportresistance then
    suportresistance = {}
    for i = 1, 20 do suportresistance[i] = 0 end
end

-- Recalcular canais apenas quando h novo pivot
if ph or pl then
    local supres = {}
    
    -- Obter canais possveis
    for x = 1, #pivotvals do
        local hi, lo, strength = get_sr_vals(x)
        if hi and lo then
            table.insert(supres, strength)  -- fora base
            table.insert(supres, hi)
            table.insert(supres, lo)
        end
    end
    
    -- Adicionar fora por toques de preo
    for x = 1, #pivotvals do
        local idx = (x - 1) * 3
        if supres[idx + 2] and supres[idx + 3] then
            local h = supres[idx + 2]
            local l = supres[idx + 3]
            local s = 0
            for y = 0, math.min(loopback, current_index) do
                if (high[y] <= h and high[y] >= l) or (low[y] <= h and low[y] >= l) then
                    s = s + 1
                end
            end
            supres[idx + 1] = supres[idx + 1] + s
        end
    end
    
    -- Resetar e selecionar os mais fortes
    for i = 1, 20 do suportresistance[i] = 0 end
    
    local src = 1
    for _ = 1, #pivotvals do
        local stv = -1
        local stl = -1
        for y = 1, #pivotvals do
            local idx = (y - 1) * 3 + 1
            if supres[idx] and supres[idx] > stv and supres[idx] >= minstrength * 20 then
                stv = supres[idx]
                stl = y
            end
        end
        if stl ~= -1 then
            local idx = (stl - 1) * 3
            local hh = supres[idx + 2]
            local ll = supres[idx + 3]
            suportresistance[(src - 1) * 2 + 1] = hh
            suportresistance[(src - 1) * 2 + 2] = ll
            
            -- Zerar força dos pivots já usados
            for y = 1, #pivotvals do
                local y_idx = (y - 1) * 3 + 1
                if supres[y_idx] and supres[y_idx + 1] and supres[y_idx + 2] then
                    local ph_val = supres[y_idx + 1]
                    local pl_val = supres[y_idx + 2]
                    if (ph_val <= hh and ph_val >= ll) or (pl_val <= hh and pl_val >= ll) then
                        supres[y_idx] = -1
                    end
                end
            end
            src = src + 1
            if src > 10 then break end
        else
            break
        end
    end
end

-- Função para cor do canal
local function get_color(ind)
    if ind <= 0 or ind > #suportresistance then
        return nil
    end
    local high_level = suportresistance[ind]
    local low_level = suportresistance[ind + 1]
    
    -- Validar valores
    if not high_level or not low_level or high_level == 0 or low_level == 0 then
        return nil
    end
    
    local current_close = close[0]
    if high_level > current_close and low_level > current_close then
        return res_col      -- Resistência (acima do preço)
    elseif high_level < current_close and low_level < current_close then
        return sup_col      -- Suporte (abaixo do preço)
    else
        return inch_col     -- Preço dentro do canal
    end
end

-- Plotar os canais (mximo 5, pois maxnumsr = 5 aps -1)
for x = 0, math.min(9, maxnumsr) do
    local idx = x * 2 + 1
    if suportresistance[idx] and suportresistance[idx] ~= 0 then
        local col = get_color(idx)
        if col then
            plot(suportresistance[idx],     "SR High " .. x, col)
            plot(suportresistance[idx + 1], "SR Low "  .. x, col)
        end
    end
end