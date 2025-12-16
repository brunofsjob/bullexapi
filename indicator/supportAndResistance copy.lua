-- Support Resistance Channels
-- Converted from PineScript to QuadCode (Lua)
-- Original: © LonesomeTheBlue (Mozilla Public License 2.0)

-- Declaração do instrumento
instrument { 
    name = "Support Resistance Channels", 
    short_name = "SRchannel",
    overlay = true 
}

-- Inputs e configurações
input_group {
    "Settings",
    prd = input { default = 10, name = "Pivot Period", type = input.integer, min = 4, max = 30 },
    ppsrc = input { default = "High/Low", name = "Source", type = input.string_selection, items = {"High/Low", "Close/Open"} },
    ChannelW = input { default = 5, name = "Maximum Channel Width %", type = input.integer, min = 1, max = 8 },
    minstrength = input { default = 1, name = "Minimum Strength", type = input.integer, min = 1 },
    maxnumsr = input { default = 6, name = "Maximum Number of S/R", type = input.integer, min = 1, max = 10 },
    loopback = input { default = 290, name = "Loopback Period", type = input.integer, min = 100, max = 400 }
}

input_group {
    "Colors",
    res_col = input { default = "#FF0000", name = "Resistance Color", type = input.color },
    sup_col = input { default = "#00FF00", name = "Support Color", type = input.color },
    inch_col = input { default = "#808080", name = "Color When Price in Channel", type = input.color }
}

input_group {
    "Extras",
    showpp = input { default = false, name = "Show Pivot Points", type = input.plot_visibility },
    showsrbroken = input { default = false, name = "Show Broken Support/Resistance", type = input.plot_visibility },
    showthema1en = input { default = false, name = "MA 1", type = input.plot_visibility },
    showthema1len = input { default = 50, name = "MA 1 Length", type = input.integer },
    showthema1type = input { default = "SMA", name = "MA 1 Type", type = input.string_selection, items = {"SMA", "EMA"} },
    showthema2en = input { default = false, name = "MA 2", type = input.plot_visibility },
    showthema2len = input { default = 200, name = "MA 2 Length", type = input.integer },
    showthema2type = input { default = "SMA", name = "MA 2 Type", type = input.string_selection, items = {"SMA", "EMA"} }
}

-- Ajustar maxnumsr (subtrair 1 como no original)
maxnumsr = maxnumsr - 1

-- Calcular Moving Averages
local ma1 = nil
local ma2 = nil

if showthema1en then
    if showthema1type == "SMA" then
        ma1 = sma(close, showthema1len)
    else
        ma1 = ema(close, showthema1len)
    end
end

if showthema2en then
    if showthema2type == "SMA" then
        ma2 = sma(close, showthema2len)
    else
        ma2 = ema(close, showthema2len)
    end
end

-- Plot Moving Averages
if ma1 then
    plot(ma1, "MA 1", rgb(0, 0, 255))
end

if ma2 then
    plot(ma2, "MA 2", rgb(255, 0, 0))
end

-- Determinar source para pivots
local src1, src2
if ppsrc == "High/Low" then
    src1 = high
    src2 = low
else
    src1 = math.max(close, open)
    src2 = math.min(close, open)
end

-- Função para calcular Pivot High (simplificada)
-- No QuadCode, precisamos implementar a lógica manualmente
local function pivothigh(source, leftbars, rightbars)
    if current_index < leftbars + rightbars then
        return nil
    end
    
    local pivot_value = source[rightbars]
    local is_pivot = true
    
    -- Verificar barras à esquerda
    for i = 1, leftbars do
        if source[rightbars + i] >= pivot_value then
            is_pivot = false
            break
        end
    end
    
    -- Verificar barras à direita
    if is_pivot then
        for i = 0, rightbars - 1 do
            if source[i] > pivot_value then
                is_pivot = false
                break
            end
        end
    end
    
    return is_pivot and pivot_value or nil
end

-- Função para calcular Pivot Low (simplificada)
local function pivotlow(source, leftbars, rightbars)
    if current_index < leftbars + rightbars then
        return nil
    end
    
    local pivot_value = source[rightbars]
    local is_pivot = true
    
    -- Verificar barras à esquerda
    for i = 1, leftbars do
        if source[rightbars + i] <= pivot_value then
            is_pivot = false
            break
        end
    end
    
    -- Verificar barras à direita
    if is_pivot then
        for i = 0, rightbars - 1 do
            if source[i] < pivot_value then
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

-- Calcular largura máxima do canal S/R
local prdhighest = highest(high, 300)
local prdlowest = lowest(low, 300)
local cwidth = (prdhighest - prdlowest) * ChannelW / 100

-- Arrays para armazenar pivot levels (em Lua usamos tabelas)
if not pivotvals then
    pivotvals = {}
    pivotlocs = {}
end

-- Adicionar novos pivots
if ph or pl then
    table.insert(pivotvals, 1, ph or pl)
    table.insert(pivotlocs, 1, current_index)
    
    -- Remover pivots antigos
    local i = #pivotvals
    while i > 0 do
        if current_index - pivotlocs[i] > loopback then
            table.remove(pivotvals)
            table.remove(pivotlocs)
        else
            break
        end
        i = i - 1
    end
end

-- Função para encontrar valores de S/R de um pivot
local function get_sr_vals(ind)
    if ind > #pivotvals then
        return nil, nil, 0
    end
    
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

-- Inicializar array de suporte/resistência
if not suportresistance then
    suportresistance = {}
    for i = 1, 20 do
        suportresistance[i] = 0
    end
end

-- Calcular e ordenar canais S/R quando encontramos novo pivot
if ph or pl then
    local supres = {}
    local stren = {}
    for i = 1, 10 do
        stren[i] = 0
    end
    
    -- Obter níveis e forças
    for x = 1, #pivotvals do
        local hi, lo, strength = get_sr_vals(x)
        if hi and lo then
            table.insert(supres, strength)
            table.insert(supres, hi)
            table.insert(supres, lo)
        end
    end
    
    -- Adicionar força baseada em H/L
    for x = 1, #pivotvals do
        local idx = (x - 1) * 3
        if supres[idx + 2] and supres[idx + 3] then
            local h = supres[idx + 2]
            local l = supres[idx + 3]
            local s = 0
            
            for y = 0, math.min(loopback, current_index) do
                local h_y = high[y]
                local l_y = low[y]
                if (h_y <= h and h_y >= l) or (l_y <= h and l_y >= l) then
                    s = s + 1
                end
            end
            
            if supres[idx + 1] then
                supres[idx + 1] = supres[idx + 1] + s
            end
        end
    end
    
    -- Resetar níveis S/R
    for i = 1, 20 do
        suportresistance[i] = 0
    end
    
    -- Obter S/Rs mais fortes
    local src = 1
    for x = 1, #pivotvals do
        local stv = -1
        local stl = -1
        
        for y = 1, #pivotvals do
            local idx = (y - 1) * 3 + 1
            if supres[idx] and supres[idx] > stv and supres[idx] >= minstrength * 20 then
                stv = supres[idx]
                stl = y
            end
        end
        
        if stl >= 0 then
            local idx = (stl - 1) * 3
            local hh = supres[idx + 2]
            local ll = supres[idx + 3]
            
            if hh and ll then
                suportresistance[(src - 1) * 2 + 1] = hh
                suportresistance[(src - 1) * 2 + 2] = ll
                stren[src] = supres[idx + 1]
                
                -- Zerar força dos pivots incluídos
                for y = 1, #pivotvals do
                    local y_idx = (y - 1) * 3
                    if supres[y_idx + 2] and supres[y_idx + 3] then
                        if (supres[y_idx + 2] <= hh and supres[y_idx + 2] >= ll) or
                           (supres[y_idx + 3] <= hh and supres[y_idx + 3] >= ll) then
                            supres[y_idx + 1] = -1
                        end
                    end
                end
                
                src = src + 1
                if src > 10 then
                    break
                end
            end
        end
    end
end

-- Função para obter cor do canal
local function get_color(ind)
    if ind > #suportresistance or suportresistance[ind] == 0 then
        return nil
    end
    
    local high_level = suportresistance[ind]
    local low_level = suportresistance[ind + 1]
    
    if high_level > close[0] and low_level > close[0] then
        return res_col
    elseif high_level < close[0] and low_level < close[0] then
        return sup_col
    else
        return inch_col
    end
end

-- Plot canais S/R (simplificado - QuadCode pode ter limitações para boxes)
-- No QuadCode, usamos plot com fill para simular canais
for x = 0, math.min(9, maxnumsr) do
    local idx = x * 2 + 1
    if suportresistance[idx] and suportresistance[idx] ~= 0 then
        local srcol = get_color(idx)
        if srcol then
            -- Plot linha superior
            plot(suportresistance[idx], "SR High " .. x, srcol)
            -- Plot linha inferior  
            plot(suportresistance[idx + 1], "SR Low " .. x, srcol)
            -- Nota: fill entre linhas pode não estar disponível no QuadCode básico
        end
    end
end

-- Verificar resistência/suporte quebrado
local resistancebroken = false
local supportbroken = false
local not_in_a_channel = true

for x = 0, math.min(9, maxnumsr) do
    local idx = x * 2 + 1
    if suportresistance[idx] and suportresistance[idx] ~= 0 then
        if close[0] <= suportresistance[idx] and close[0] >= suportresistance[idx + 1] then
            not_in_a_channel = false
            break
        end
    end
end

if not_in_a_channel then
    for x = 0, math.min(9, maxnumsr) do
        local idx = x * 2 + 1
        if suportresistance[idx] and suportresistance[idx] ~= 0 then
            if close[1] <= suportresistance[idx] and close[0] > suportresistance[idx] then
                resistancebroken = true
            end
            if close[1] >= suportresistance[idx + 1] and close[0] < suportresistance[idx + 1] then
                supportbroken = true
            end
        end
    end
end

-- Plot sinais de quebra (se habilitado)
if showsrbroken then
    if resistancebroken then
        plot_shape(low[0], "Resistance Broken", shape_style.triangleup, rgb(0, 255, 0))
    end
    if supportbroken then
        plot_shape(high[0], "Support Broken", shape_style.triangledown, rgb(255, 0, 0))
    end
end
