local Loader = assert(LOMModLoader, "LOMModLoader is required")

local VERSION = "0.9.46"
local CIRCUIT_BREAKER_TIPS_ID = 6427242
local CIRCUIT_BREAKER_TEXT = "If the server is too crowded, it will enter a circuit-breaker state, temporarily preventing new accounts that have not created a character on the current server from queuing. Please choose another server that is not under a circuit-breaker to experience the game."

-- Production performance mode keeps warnings and errors while removing the
-- release/info traffic emitted from hot gameplay paths. It also disables the
-- packaged large-allocation diagnostic check without changing rendering or
-- gameplay behavior. Set PerformanceMode=false in cpdd_user_settings.lua to
-- restore the game's defaults on the next launch.
(function()
    Loader.Telemetry = Loader.Telemetry or {}
    local function applyPerformanceMode(stage)
        if type(Loader.Features) == "table" and Loader.Features.PerformanceMode == false then
            Loader.Telemetry.PerformanceMode = { Disabled = true, Stage = stage }
            Loader.Telemetry.PerformanceModeApplied = false
            return false
        end
        local results = {
            Stage = stage,
            NativeLogLevel = false,
            LogCategories = 0,
            LargeAllocationChecks = false,
        }
        local warningLevel = 5
        -- Unreal-backed globals can be exposed through the module environment's
        -- __index path. Normal lookup is required; rawget(_G, ...) silently
        -- misses them in the shipping runtime.
        local levels = LogLevel
        if type(levels) == "table" and tonumber(levels.Warning) ~= nil then
            warningLevel = tonumber(levels.Warning)
        end

        local gameLog = Log
        if type(gameLog) == "table" then
            gameLog.Level = warningLevel
        end
        local nativeLogger = LuaCLogger
        if nativeLogger ~= nil and type(nativeLogger.SetGameLogLevel) == "function" then
            results.NativeLogLevel = pcall(nativeLogger.SetGameLogLevel, warningLevel)
        end

        local context = nil
        local getContext = GetContextObject
        if type(getContext) == "function" then
            local contextOk, contextValue = pcall(getContext)
            if contextOk then context = contextValue end
        end
        local systemOk, systemLibrary = pcall(import, "KismetSystemLibrary")
        local execute = systemOk and systemLibrary and systemLibrary.ExecuteConsoleCommand
        if type(execute) == "function" then
            for _, category in ipairs({
                "LuaLog",
                "UBaseAnimInstanceLog",
                "LogFaceControlComponent",
                "RoleCompositeMgrLog",
            }) do
                if pcall(execute, context, "Log " .. category .. " Warning", nil) then
                    results.LogCategories = results.LogCategories + 1
                end
            end
        end

        local libraryOk, library = pcall(import, "LuaFunctionLibrary")
        local intSetter = libraryOk and library and (
            library.ChangeConsoleVariableOfIntWithCurrentPriority
            or library.ChangeConsoleVariableOfInt
        )
        if type(intSetter) == "function" then
            results.LargeAllocationChecks = pcall(
                intSetter,
                "memory.EnableLargeAllocationChecks",
                0
            )
        end
        Loader.Telemetry.PerformanceMode = results
        Loader.Telemetry.PerformanceModeApplied = results.NativeLogLevel
        return results.NativeLogLevel
    end

    applyPerformanceMode("module")
    if type(Loader.On) == "function" then
        Loader.On("after_main", function()
            if applyPerformanceMode("after_main") then
                local nativeLogger = LuaCLogger
                if nativeLogger ~= nil and type(nativeLogger.Warning) == "function" then
                    pcall(
                        nativeLogger.Warning,
                        "[CPDDPerformance] active: release logs suppressed; diagnostics disabled"
                    )
                end
            end
        end, 2000000, "cpdd.runtime-fix.performance-mode")
    end
end)()

local aggregateOverrides = {
    -- Equipment reform paints these season-lock messages into a narrow banner.
    -- Override the already-English StringDB rows themselves so the explicit
    -- line break survives even when no Chinese runtime-map lookup occurs.
    [413898750559745] = "A herança de afixos está disponível.\nA remodelação é desbloqueada em %s dias.",
    [413898750560769] = "A herança de afixos está disponível.\nA remodelação não está disponível no momento.",
    -- Player Details exposes two distinct mechanics that the old catalog
    -- translated identically. Keep their labels unambiguous, including the
    -- expanded physical and magic defense-break rows.
    [255431368783360] = "Quebra de Escudo",
    [141494476346368] = "Quebra de defesa",
    [255431368777472] = "Quebra de Defesa Física",
    [255431368780800] = "Quebra de Defesa Mágica",
    -- Launch 1.1 Esc-menu compact labels. These are the confirmed four-row
    -- values from esc_menu_hotfix_v2 and must win over the external StringDB.
    [74905303409152] = "Explorar",
    [466331174441472] = "Arquivo",
    [501378376016640] = "Estilo",
    [514572247120128] = "Fantoches",
    [527972545072640] = "História",
    [625210604657664] = "Contatos",
    [712484608544768] = "Vitórias fáceis",
    [774126247610880] = "Equipamento",
    [774126784481024] = "Artefatos",
    [866415967995648] = "Frente de guerra",
    [866622663296512] = "Cidade Negra",
    [884214580905472] = "Avançar",
    [933074128867328] = "Artes",
    [989630258218752] = "Talentos",
    [1020416583796224] = "Pular",
    [1020416583796480] = "Análise",
    [936784443737600] = "Beyonder Avaliação",
    [936990870604032] = "Prévia da recompensa",
    [1271036247030528] = "Reivindicado",
    [620129389936640] = "Usar",
    [1073124154021632] = "Configurações de desmontagem automática",
    [1073124154089984] = "Em uso",
    [1073124154205952] = "Minhas construções",
    [1073124154228480] = "Confirmação de desmontagem automática",
    [1073124154229760] = "Versão oficial recomendada",
    [1271036247052800] = "Construções recomendadas",
    [1068726107902976] = "Códice",
    [1271036247021824] = "Clique na área em branco para fechar",
    [1240251532142337] = [=[1. <Highlight>Family Application:</> Any Beyonder who has not joined a family can publish a personal application to find a suitable family. The application is automatically withdrawn <Highlight>3 days</> after publication or after successfully joining a family.
2. <Highlight>Recruitment Response:</> Beyonders who have not joined a family may start a recruitment response or join one started by another Beyonder. The initiator becomes the <Highlight>Family Chief</> by default.
3. <Highlight>Create Family:</> During the recruitment-response phase, a family can be created once at least <Highlight>3 people</> have responded. During creation, the Chief can adjust the family name and member positions.
4. <Highlight>Join Family:</> When a family has fewer than <Highlight>14 members</>, the Chief can recruit. Other Beyonders may apply and join directly after the Chief approves their application.]=],
    [1271036247235584] = "Construções de equipamentos",
    [312331095508480] = "Comentários",
    [1068726108208384] = "%d 0%% Preço",
    -- Manor upgrade UI splits these records on commas. Preserve the data
    -- contract instead of using the prose-style colon from the old patch.
    [677369761236481] = "Novo recurso desbloqueado, visite os castelos dos amigos",
    [677369761236737] = "Novo recurso desbloqueado, Workshop",
    -- Launch 1.2 EquipmentUniqueData rows 6801-6803. These values are cached
    -- while the data module loads, so translate the authoritative StringDB IDs
    -- in addition to repairing ItemTipsEquipSpecial:SetData below.
    [409365949475072] = "<CostRed> {1,2,(Marca inativa)} </> Aprimoramento de habilidade aumentado em <Mark> 30 </> .\nNão entra em vigor enquanto o conjunto <Mark> Eco de Espírito e Conhecimento </> estiver ativo.",
    [409365949475328] = "<CostRed> {1,2,(Marca inativa)} </> Depois de usar uma habilidade de limpeza, ganhe <Mark> 50 </> Bloqueio de habilidade por <Mark> 10 </> segundos. Pode ser acionado no máximo uma vez a cada <Mark> 30 </> segundos.\nNão tem efeito enquanto o conjunto <Mark> Echo of Spirit and Knowledge </> estiver ativo.",
    [409365949475584] = "<CostRed> {1,2,(Marca inativa)} </> Quebra de armadura aumentada em <Mark> 80 </> . Ao receber dano, há uma chance de ganhar <Mark> 60 </> de Defesa por <Mark> 5 </> segundos. Pode ser acionado no máximo uma vez a cada <Mark> 10 </> segundos.\nNão tem efeito enquanto o conjunto <Mark> Echo of Spirit and Knowledge </> estiver ativo.",
    [211107843337216] = "As correntes de vedação do domínio “Porta” enrolam-se em torno do seu coração para evitar danos fatais. Um único golpe não pode reduzir seu HP em mais de 25% do HP máximo.",
    [211107843655936] = [=[When a class combat skill enters cooldown, the cooldown is immediately refunded. If it is a charged skill, all charge counts are refunded. Each individual skill can trigger this refund at most once. {CheckStar(Type="selado",ID=2085021)=1?The refunded skill deals <Yellow>*f**</> less damage and healing.}{CheckStar(Type="selado",ID=2085021)=3?The refunded skill additionally gains <Yellow>*f**</> damage and healing.}]=],
    [211107844315392] = "Senhorita Justiça testemunhou sua queda e viu você se levantar novamente. Uma vontade que foi vista não se extinguirá facilmente. O dano recebido é reduzido em 30% e o dano causado é aumentado em 40%.",
    [286012073289984] = "“O branco puro que dorme dentro do casulo carmesim, a criança divina que governa o renascimento e a corrupção, a possibilidade final no fim dos dias.”",
    [286012610526208] = "\"Uau, uau!\"",
    [1240251532052225] = "O Sr. Tolo enxertou em você um destino do futuro, permitindo que você exerça o poder de sequências superiores. À medida que sua força aumenta, a variedade e o poder das habilidades que você aprende continuarão a aumentar. As habilidades são divididas em três categorias: Habilidades de Combate, Habilidades Especiais e Habilidades de Atuação. Você pode equipar até quatro habilidades de combate ou habilidades de atuação ao mesmo tempo. Habilidades Especiais não precisam ser equipadas e incluem Ataque Básico, Quebra de Controle de Multidão e Habilidades de Finalização.",
}

local splitOverrides = {
    buffappear = {
        [1253512780450048] = "Temer",
    },
    buffdata = {
        [1253512780450048] = "Temer",
    },
    debug = {
        [1169950433818880] = "Entre no sonho",
    },
    monsterskill = {
        [1271036247082752] = "Projeção",
    },
    skill = {
        [1240389776443904] = "Corte Purificador",
    },
    skill1 = {
        [1240389776521984] = "Golpe Estelar",
    },
    skill2 = {
        [611398258279936] = "Farol da História",
    },
    skill3 = {
        [998771022409216] = "Corte da Nebulosa",
    },
    spellfield = {
        [1068726107518720] = "Dica",
    },
}

local stringConstOverrides = {
    BAG_AUTO_AUTO_RESOLVE_TITLE = "Confirmação de desmontagem automática",
    BAG_AUTO_DECOMPOSE_TITLE = "Configurações de desmontagem automática",
    COMMENT_PANEL_TITLE = "Comentários",
    DIALOGUE_SKIP = "Pular",
    EQUIPMENT_PLAN_APPLY_CURRENT_PLAN = "Aplicar compilação",
    FASHION_APPEARANCE = "Aparência",
    FASHION_DYE_MY_PLAN = "Minhas construções",
    GUILD_CARGO_HUB_REWARD_COMPLETE = "Reivindicado",
    GVG_HONOR_CLAIMED_TEXT = "Reivindicado",
    ITEM_GOT = "Reivindicado",
    MONTH_CARD_MAIN_PAGE_TODAY_RECEIVED_LABEL = "(Reivindicado hoje)",
    FAMILY_INVITE_SHARE_TEAM = "Canal de festa",
    FAMILY_INVITE_SHARE_WORLD = "Canal Mundial",
    FAMILY_MEMBER_COUNT_FMT = "Membros atuais da família: %s /14",
    FAMILY_MEMBER_FMT = "Membros da família (%d / %d )",
    ONE_CLICK_IN_USE = "Em uso",
    ONE_CLICK_RECOMMEND_PLAN = "Versão oficial recomendada",
    ONE_CLICK_SHARE_RECOMMEND_PLAN = "Construções recomendadas",
    ONE_CLICK_TITLE = "Assistência com um clique",
    ONE_CLICK_USE = "Usar",
    TRAINTRADE_ITEM_DISCOUNT_CHINESE = "%d 0%% Preço",
    MAP_PVP_LAST_HUNT_DRAGON_BOSS_BELONG_FORMAT = "<Green> %s </> Afiliação da equipe",
    MAP_PVP_LAST_HUNT_DRAGON_BOSS_NAME = "Projeção do Dragão",
    MAP_PVP_LAST_HUNT_DRAGON_BOSS_NOT_BELONG_FORMAT = "<Red> %s </> Afiliação da equipe",
    PVP_LAST_HUNT_ACTIVE_TIME_FORMAT = "Ativando %M:%S",
    PVP_LAST_HUNT_ACTIVITY_NOT_OPEN_TEXT = "Use <Highlight> Semente de Suspiros </> para ativar o Poder dos Suspiros, inicie os Suspiros Missão e complete-o para receber recompensas valiosas.",
    PVP_LAST_HUNT_ACTIVITY_OPEN_FORMAT = "Começa em %H horas %M minutos",
    PVP_LAST_HUNT_ACTIVITY_OPEN_TEXT = "Hora de início do evento",
    PVP_LAST_HUNT_ACTIVITY_REWARD_PREVIEW_FORMAT = "Missão Recompensas",
    PVP_LAST_HUNT_BOSS_BUTTON_DESC = "Ir",
    PVP_LAST_HUNT_BOSS_CONTENT_DESC = "Espaço reservado para descrição do dragão da cidade real",
    PVP_LAST_HUNT_BOSS_DETAIL_CONDITION_TITLE = "Atualizar status",
    PVP_LAST_HUNT_BOSS_DETAIL_CONTENT = "Derrote monstros de elite para ganhar recompensas abundantes",
    PVP_LAST_HUNT_BOSS_DETAIL_NOT_SPAWNED = "O alvo ainda não apareceu",
    PVP_LAST_HUNT_BOSS_DETAIL_SPAWNED = "O alvo apareceu",
    PVP_LAST_HUNT_BOSS_DETAIL_TITLE = "Alvo de caça",
    PVP_LAST_HUNT_BOSS_DRAGON_FORMAT = "Dragão aparece em %M:%S",
    PVP_LAST_HUNT_BOSS_SECOND_TITLE = "Derrote o Dragão da Cidade Real",
    PVP_LAST_HUNT_BOSS_TAG_NAME = "Guardião Real da Cidade",
    PVP_LAST_HUNT_BOSS_TITLE = "Mate o Dragão",
    PVP_LAST_HUNT_CAMP_SUBMIT_FORMAT = "%s Ponto de envio",
    PVP_LAST_HUNT_CHAT_BUTTON_TEXT = "Ir",
    PVP_LAST_HUNT_CHAT_TITLE = "Buzina",
    PVP_LAST_HUNT_CROSS_SERVER_SCORE_TITLE = "Mérito Militar",
    PVP_LAST_HUNT_DETAIL_MY_DATA_TAB = "Meus dados",
    PVP_LAST_HUNT_DETAIL_RANK_TAB = "Classificação",
    PVP_LAST_HUNT_FIGHT_ASSISTANT_FORMAT = "%s foi derrotado por %s em %s . Suporte necessário!",
    PVP_LAST_HUNT_FIGHT_KILL_RESULT_FORMAT = "%s caçado com sucesso %s em %s !",
    PVP_LAST_HUNT_GUILD_ACTIVITY_DESC_TIPS = "Final Hunt Dragon Raide <Highlight> [Leilão de equipe] </>: %d / %d (nesta sexta-feira) às 19:10",
    PVP_LAST_HUNT_GUILD_NAME_FORMAT = "<Enemy_Name> %s </> Clube",
    PVP_LAST_HUNT_HIGHER_DETAIL_CONTENT = "Área avançada missão contendo muitos monstros fora de controle",
    PVP_LAST_HUNT_HIGHER_DETAIL_NOT_OPENED_TITLE = "Atualmente fechado",
    PVP_LAST_HUNT_HIGHER_DETAIL_OPENED_TIME = "Aberto diariamente: 19h00-21h00\nHorário adicional: sábado e domingo, 14h00-16h00",
    PVP_LAST_HUNT_HIGHER_DETAIL_TITLE_NAME = "Avançado · Maré",
    PVP_LAST_HUNT_HUD_PROGRESS_CURRENCY_FORMAT = "<Highlight> %s </> / %s",
    PVP_LAST_HUNT_HUD_PROGRESS_FORMAT = "<Highlight> %d </> / %d",
    PVP_LAST_HUNT_ITEM_CAN_NOT_USE = "Quantidade insuficiente",
    PVP_LAST_HUNT_LACK_USE_ITEM_PROP_COUNT_FORMAT = "Tentativas restantes: %s",
    PVP_LAST_HUNT_MAIN_PROGRESS_TITLE = "Prévia da recompensa",
    PVP_LAST_HUNT_MAP_DETAIL_DESC = "Entrada de teletransporte da área da facção",
    PVP_LAST_HUNT_MAP_ITEM_NAME = "Semente de Suspiros · Área de Maré Monstruosa",
    PVP_LAST_HUNT_MEMBER_COUNT_FORMAT = "(Membros do grupo: %d / %d )",
    PVP_LAST_HUNT_MONSTER_CANCEL_BUTTON_NAME = "Cancelar",
    PVP_LAST_HUNT_MONSTER_DROP_REWARD_TEXT = "Chance de cair de <HyperLink stylename=\"Clickable\" u=\"\"> monstros menores </> derrotados",
    PVP_LAST_HUNT_MONSTER_DROP_REWARD_UNDERLINE_TEXT = "Chance de cair de <HyperLink stylename=\"Underline\" u=\"\"> monstros menores </> derrotados",
    PVP_LAST_HUNT_MONSTER_RECOMMEND_GROUP = "Grupo recomendado",
    PVP_LAST_HUNT_MONSTER_RECOMMEND_TEAM = "Festa recomendada",
    PVP_LAST_HUNT_MONSTER_SUMMON_BUTTON_NAME = "Vá para convocar",
    PVP_LAST_HUNT_MONSTER_SUMMON_LEFT_COUNT_FORMAT = "Convocações restantes esta semana: %d",
    PVP_LAST_HUNT_NOT_OPENED_BUTTON_TEXT = "Disponível quando o evento começar",
    PVP_LAST_HUNT_RANK_TAB_GUILD_NAME = "Clube",
    PVP_LAST_HUNT_RANK_TAB_PERSONAL_NAME = "Pessoal",
    PVP_LAST_HUNT_RESURGENCE_TIPS = "Selecione um ponto ressurgir e clique em Ir",
    PVP_LAST_HUNT_RESURGENCE_TITLE = "Selecione Ressurgir Ponto",
    PVP_LAST_HUNT_REVIVE_BUTTON_NAME = "Vá para Ressurgir",
    PVP_LAST_HUNT_REWARD_PREVIEW_TITLE = "Missão Visualização da recompensa",
    PVP_LAST_HUNT_SCORE_TITLE = "Pontos de classificação",
    PVP_LAST_HUNT_SEND_BUTTON_TITLE = "Enviar buzina",
    PVP_LAST_HUNT_SEND_CHAT_DEFAULT_TEXT = "Irmãos, venham me ajudar",
    PVP_LAST_HUNT_SEND_DEFAULT_TIP_TEXT = "Convocar até %d jogadores",
    PVP_LAST_HUNT_SEND_PANEL_TIPS = "Convoque até 14 jogadores",
    PVP_LAST_HUNT_SEND_PANEL_TITLE = "Enviar buzina",
    PVP_LAST_HUNT_SETTLE_MENT_ASSIST_NUM_TITLE = "Assistências",
    PVP_LAST_HUNT_SETTLE_MENT_CANCEL = "Cancelar",
    PVP_LAST_HUNT_SETTLE_MENT_KILL_NUM_TITLE = "Mata",
    PVP_LAST_HUNT_SETTLE_MENT_LEAVE = "Teleporte para longe",
    PVP_LAST_HUNT_SETTLE_MENT_PROGRESS_NUM_TITLE = "Liquidação de caça",
    PVP_LAST_HUNT_SETTLE_MENT_SCORE_NUM_TITLE = "Pontos de classificação",
    PVP_LAST_HUNT_SETTLE_MENT_TITLE = "Liquidação de caça",
    PVP_LAST_HUNT_SUBMIT_CONTENT = "Envie Relíquia Escarlate materiais em troca de vouchers de caça",
    PVP_LAST_HUNT_SUBMIT_REFRESH_DESC = "O Mordomo Caçador muda de posição no mapa a cada 30 minutos. Mais mordomos aparecem quando o combate é intenso.",
    PVP_LAST_HUNT_SUBMIT_REFRESH_TITLE = "Atualizar regras",
    PVP_LAST_HUNT_SUBMIT_TITLE = "Mordomo Caçador",
    PVP_LAST_HUNT_SUMMON_AUTHOER_FORMAT = "(Convocado por: %s )",
    PVP_LAST_HUNT_SUMMON_MONSTER_GET_NUM = "Tentativas obtidas",
    PVP_LAST_HUNT_SUMMON_MONSTER_LACK_NUM = "Nenhuma tentativa permanece esta semana. Ganhe vouchers Hunt para obter mais.",
    PVP_LAST_HUNT_TASK_BUFF_NAME = "Poder dos Suspiros",
    PVP_LAST_HUNT_TASK_COMMIT_TEXT = "Vá para enviar",
    PVP_LAST_HUNT_TASK_FINISH_TITLE_TEXT = "Terminou",
    PVP_LAST_HUNT_TASK_FRAGMENT_NAME = "Fragmento de Presa",
    PVP_LAST_HUNT_TASK_NOT_ACTIVE_CONTENT_TEXT = "Use uma Semente de Suspiros, derrote monstros ou saqueie jogadores para obter Fragmentos de Presa e, em seguida, envie-os ao Conde da Ordem para receber recompensas.",
    PVP_LAST_HUNT_TASK_NOT_ACTIVE_FINISH_TEXT = "O missão terminou. Encontre o Conde da Ordem para enviar seus fragmentos para recompensas.",
    PVP_LAST_HUNT_TASK_NOT_ACTIVE_TEXT = "Inativo",
    PVP_LAST_HUNT_TASK_PROGRESS_TEXT = "Progresso da caça",
    PVP_LAST_HUNT_TASK_PROP_TEXT = "Semente de Suspiros",
    PVP_LAST_HUNT_TASK_QUICK_TEAM = "Festa Rápida",
    PVP_LAST_HUNT_TASK_TITLE_NAME = "Caçada Final",
    PVP_LAST_HUNT_TITLE_DETAIL_NAME = "Detalhes",
    PVP_LAST_HUNT_TITLE_FOLD_NAME = "Colapso",
    PVP_LAST_HUNT_USE_ITEM_NOT_ACTIVITY_OPEN_FORMAT = "Não pode ser usado fora do horário do evento. Hora do evento: <highlight> %s - %s </>",
    PVP_LAST_HUNT_USE_ITEM_PROP_DESC = "Usando a Semente dos Suspiros...",
    PVP_LAST_HUNT_USE_TASK_TEXT_NAME = "Vá para Aceitar Missão",
    RED_PACKET_ALREADY_RECEIVED = "Reivindicado",
    SECRET_PARTNER_BTN_ALREADY_CHANGE_ACTOR_NAME = "Mudança",
    SECRET_PARTNER_BTN_CHANGE_ACTOR_NAME = "Mudança",
    SECRET_PARTNER_CANCEL_CHANGE_ACTOR = "Cancelar turno",
    SECRET_PARTNER_CHANGE_ACTOR_TITLE = "Mudar alvo",
    SECRET_PARTNER_SKILL_TEXT = "Marionete Habilidade",
    SECRET_PARTNER_STAR_UP_TEXT_FORMAT = "Sequência %d",
    SKILL_PRESET_TAB_1 = "Construções recomendadas",
    TASK_TRACE_DISTANCE = "eu",
    TRINITY_ALL_TREASURE_HAVE_CLAIMED = "Todas as recompensas reivindicadas",
    TEAM_INVITE_SECRET_PARTNER_TITLE = "Aplicação de Ilusão",
    UIAPPEARANCE_USE = "Usar",
    UIAPPEARANCE_USING = "Em uso",
}

-- This quest validates the literal Chinese chat input server-side. Keep only
-- the password Chinese so the surrounding quest instructions remain English.
local QUEST_CHAT_PASSWORD_EN = "The storm is stronger than spirits"
local QUEST_CHAT_PASSWORD_ZH = "风暴比烈酒更烈"
local ENTER_WORLD_LABEL_LONG = "Enter the Extraordinary World"
local ENTER_WORLD_LABEL_SHORT = "Enter World"

local function shortenEnterWorldLabel(value)
    if value == ENTER_WORLD_LABEL_LONG then
        return ENTER_WORLD_LABEL_SHORT
    end
    return value
end

local function restoreQuestChatPassword(value)
    if type(value) ~= "string" or not value:find(QUEST_CHAT_PASSWORD_EN, 1, true) then
        return value
    end
    return value:gsub(QUEST_CHAT_PASSWORD_EN, function()
        return QUEST_CHAT_PASSWORD_ZH
    end)
end

-- These strings are emitted by Launch 1.2 dialogue/widgets without a stable
-- StringDB key. Keep the replacements exact or narrowly scoped so the
-- aggregate entry for 米 (which legitimately means "Rice" in chat/filter
-- data) is not changed globally.
local visibleTextExactOverrides = {
    ["机动"] = "Mobilidade",
    ["射程"] = "Faixa",
    ["Win by Lying Down"] = "Vitórias fáceis",
    ["在<h>【附近】/【世界】</>聊天栏中打字输入“<HyperLink stylename=\"h\">风暴比烈酒更烈</>”"] =
        "Type \"<HyperLink stylename=\"h\">风暴比烈酒更烈</>\" in the <h>[Nearby]/[World]</> chat bar",
    ["所向披靡，无往不利！{{player.name}}在<Chat_Highlight>{{gameMode.name}}</>中获得<Chat_Highlight>{{eventMessageParams.curWinStreak}}连胜</>，战场之上，新的神话已在书写！"] =
        "Invencível e imparável! {{player.name}} alcançou uma sequência de <Chat_Highlight> {{eventMessageParams.curWinStreak}} vitórias consecutivas </> em <Chat_Highlight> {{gameMode.name}} </> ! No campo de batalha, uma nova lenda está sendo escrita!",
    ["Invincible and unstoppable! {{player.name}} has achieved a <Chat_Highlight>{{eventMessageParams.curWinStreak}} win streak in <Chat_Highlight>{{gameMode.name}}</>! On the battlefield, a new legend is being written!</>"] =
        "Invencível e imparável! {{player.name}} alcançou uma sequência de <Chat_Highlight> {{eventMessageParams.curWinStreak}} vitórias consecutivas </> em <Chat_Highlight> {{gameMode.name}} </> ! No campo de batalha, uma nova lenda está sendo escrita!",
    ["推理检定"] = "Verificação de dedução",
    ["发现它变成了一份地图，还标注了奇迹降临的位置……"] =
        "Você descobre que ele se tornou um mapa, marcando o local onde o milagre ocorrerá...",
    ["沙利亚特"] = "Sariat",
    ["迪尼特"] = "Dinit",
    ["罗、罗茜！你今天过得好吗？"] = "R-Rosie! Como você está hoje?",
    ["罗、罗茜！你今天过得好吗?"] = "R-Rosie! Como você está hoje?",
    ["啊，弗雷泽！我很好，这束花是……"] =
        "Ah, Frazier! Estou bem. Esse buquê é...?",
    ["啊，弗雷泽！我很好，这束花是......"] =
        "Ah, Frazier! Estou bem. Esse buquê é...?",
    ["啊，弗雷泽！我很好，这束花是..."] =
        "Ah, Frazier! Estou bem. Esse buquê é...?",
    ["我想把它送给你，其实，我对你……"] =
        "Eu queria dar a você. Na verdade, eu...",
    ["我想把它送给你，其实，我对你......"] =
        "Eu queria dar a você. Na verdade, eu...",
    ["我想把它送给你，其实，我对你..."] =
        "Eu queria dar a você. Na verdade, eu...",
    ["跳过"] = "Pular",
    ["回顾"] = "Análise",
    ["截图"] = "Captura de tela",
    ["点击空白区域关闭"] = "Clique na área em branco para fechar",
    ["点击任意区域跳过"] = "Clique em qualquer lugar para pular",
    ["恭喜获得"] = "Parabéns",
    ["转化"] = "Converter",
    ["男子"] = "Homem",
    ["丑人"] = "Homem feio",
    ["愚者"] = "O tolo",
    ["“愚者”"] = "\"O Louco\"",
    ["塞巴斯蒂安"] = "Sebastião",
    ["寒巴斯蒂安"] = "Sebastião",
    ["非凡评分"] = "Beyonder Avaliação",
    ["推荐非凡评分"] = "Classificação recomendada Beyonder",
    ["奖励预览"] = "Prévia da recompensa",
    ["目标点数"] = "Pontuação alvo",
    ["黎明降临"] = "Chegada do amanhecer",
    ["仲裁烙印"] = "Marca de Arbitragem",
    ["窥秘凝视"] = "Olhar misterioso",
    ["晨曦守护"] = "Proteção contra luz matinal",
    ["骑士誓约"] = "Juramento do Cavaleiro",
    ["蝶灵附身"] = "Possessão do Espírito Borboleta",
    ["丧钟回响"] = "Eco da Sentença de Morte",
    ["头狼连爪"] = "Combinação de garras de lobo alfa",
    ["钻头守护"] = "Proteção de perfuração",
    ["未拥有"] = "Não pertencente",
    ["推荐方案"] = "Construções recomendadas",
    ["官方推荐方案"] = "Versão oficial recomendada",
    ["我的方案"] = "Minhas construções",
    ["我要变强"] = "Melhorar",
    ["要变强"] = "Melhorar",
    ["已领取"] = "Reivindicado",
    ["今日已领取"] = "Reivindicado hoje",
    ["奖励已领取"] = "Recompensa reivindicada",
    ["已领取全部奖励"] = "Todas as recompensas reivindicadas",
    ["使用"] = "Usar",
    ["使用中"] = "Em uso",
    ["图鉴"] = "Códice",
    ["跟随卡萝，来到了工厂区。"] = "Siga Carol até o Distrito da Fábrica.",
    ["全部重置"] = "Redefinir tudo",
    ["装备方案"] = "Construções de equipamentos",
    ["自动分解"] = "Desmontagem automática",
    ["获得方式"] = "Como obter",
    ["下一级效果"] = "Efeito de próximo nível",
    ["在目标位置召唤窥秘之眼，对目标造成持续伤害和减速。"] =
        "Evoca um Olho do Mistério no local alvo, causando dano contínuo e retardando o alvo.",
    ["感知灵界，观测星空，通过灵性物品启示的命运变化，解读其映射的现实空间异动、事态发展走向与潜在未知危险。"] =
        "Sinta o mundo espiritual e observe as estrelas. Interprete as mudanças no destino reveladas pelos itens espirituais para discernir os distúrbios do mundo real que eles refletem, como os eventos podem se desenrolar e os perigos potenciais desconhecidos.",
    ["占星启示期间，周围的玩家可以获得临时技能来获取占星指引。"] =
        "Durante a Revelação Astrológica, jogadores próximos podem ganhar uma habilidade temporária para receber orientação astrológica.",
    ["使自身获得武力加4，直觉加2。使用临时技能获取占星指引的玩家也可以获得武力加4，直觉加2。"] =
        "Ganhe +4 de Força e +2 de Intuição. Os jogadores que usam a habilidade temporária para receber orientação astrológica também ganham +4 de Força e +2 de Intuição.",
    ["木桩训练"] = "Boneco de treinamento",
    ["一键辅助"] = "Assistência com um clique",
    ["家族任务"] = "Missões familiares",
    ["你尚未加入任何家族"] = "Você não se juntou a uma família.",
    ["[队伍]"] = "[Equipe]",
    ["【附身能力】"] = "[Habilidade de Posse]",
    ["请选择要使用【灵体之线】的对象"] = "Selecione um alvo para [Corpo espiritual Tópicos]",
    ["附身剩余时间"] = "Tempo restante de posse",
    ["秘偶属性生效总览"] = "Marionete Visão geral dos efeitos de atributos",
    ["本频道可用传音发言"] = "As transmissões podem ser enviadas neste canal",
    ["本频道无法发言"] = "Você não pode falar neste canal",
    ["但我们的数据——"] = "Mas nossos dados—",
    ["哼唧！哼唧……"] = "Oink! Oink...",
    ["嗯……都行。"] = "Hmm... está tudo bem.",
    ["坏了，我可能把<P_Yellow>生物催长剂</>当成椰蓉洒在蛋糕上了！"] =
        "Ah, não, posso ter borrifado <P_Yellow> estimulante de biocrescimento </> no bolo em vez de coco ralado!",
    ["培根……你真是救我于水火啊……"] = "Bacon... você realmente me salvou...",
    ["培根……培根怎么回事？？"] = "Bacon... o que há de errado com Bacon??",
    ["太好了！拿到数据了！"] = "Ótimo! Conseguimos os dados!",
    ["好了。下次再来！"] = "Aí está. Venha de novo!",
    ["情况有点失控了！跑啊！"] = "Isso está ficando fora de controle! Correr!",
    ["第一次来吗？要什么口味？"] = "Primeira vez aqui? Qual sabor você gostaria?",
    ["等下我就买一大堆小蛋糕给你！"] = "Depois compro um monte de cupcakes para você!",
    ["那就给你最经典的那种吧。"] = "Então vou te dar o clássico.",
    ["霍伊大学赛艇队招新！"] = "A equipe de remo da Hoy University está recrutando!",
    ["成员列表"] = "Lista de membros",
    ["俱乐部会长"] = "Presidente do clube",
    ["正式成员"] = "Membro Pleno",
    ["候补成员"] = "Membro Reserva",
    ["可预存"] = "Pode pré-armazenar",
    ["已预存"] = "Pré-armazenado",
    ["新手"] = "Novato",
    ["赛季剧情"] = "História da temporada",
    ["提交可获得猎杀进度"] = "Envie para ganhar progresso na caça",
    ["可获得猎杀进度"] = "Ganhe progresso na caça",
    ["当前进度："] = "Progresso atual:",
    ["当前进度:"] = "Progresso atual:",
    ["击杀"] = "Mata",
    ["助攻"] = "Assistências",
    ["排行榜"] = "Tabela de classificação",
    ["技能名称"] = "Nome da habilidade",
    ["次数"] = "Contar",
    ["伤害量"] = "Dano",
    ["伤害来源"] = "Fonte de dano",
    ["寄售"] = "Consignação",
    ["终末猎杀"] = "Caçada Final",
    ["主宰争锋"] = "Confronto do Dominador",
    ["主宰之战"] = "Confronto do Dominador",
    ["副本"] = "Masmorra",
    ["秩序世界"] = "Mundo da Ordem",
    ["本周获取上限"] = "Limite Semanal",
    ["城市暗面"] = "Cidade Negra",
    ["新"] = "Novo",
    ["同家族/俱乐部队员达到3人及以上"] = "Mais de 3 membros do grupo da mesma família/clube",
    ["对比"] = "Comparar",
    ["进攻模式·PVP"] = "Modo Ofensivo · PvP",
    ["随机获得2-4个词条"] = "Concede 2 a 4 afixos aleatórios",
    ["神圣之杖"] = "Cajado Santo",
    ["线索"] = "Dica",
    ["组队跟随中..."] = "Seguindo festa...",
    ["组队跟随中…"] = "Seguindo festa...",
    ["你在廷根的集体意识中失去了形态，意识正在退回现实..."] =
        "Você perdeu a forma na consciência coletiva de Tingen. Sua consciência está voltando à realidade...",
    ["界面返回"] = "Voltar",
    ["灵体之线玩法"] = "Corpo espiritual Tópicos",
    ["廷根第一市民"] = "O primeiro cidadão de Tingen",
    ["[封]"] = "[Selado]",
    ["狂袭式"] = "Ataque Frenético",
    ["廷根守墓人"] = "Coveiro de Tingen",
    ["机器加工厂坊"] = "Oficina de processamento de máquinas",
    ["非凡材料每有1条词条格挡 +200"] = "Cada Beyonder afixo de material concede Bloqueio +200",
    ["总探索度"] = "Exploração Total",
    ["上限可累计至下周"] = "Limite não utilizado é transferido para a próxima semana",
    ["安迪哥努斯笔记"] = "Caderno Antígono",
    ["首通队伍"] = "Equipe de primeira limpeza",
    ["男子：（癫狂）万物的“母亲”，赐予我们新生！"] =
        "Homem: (Manicamente) “Mãe” de todas as coisas, conceda-nos o renascimento!",
    ["“愚者”：拿上这个。"] = "\"O Louco\": Pegue isso.",
    ["丑人：（有效期十四年？为什么要签这么久的合同……）"] =
        "Homem Feio: (Válido por quatorze anos? Por que eu precisaria assinar um contrato tão longo...)",
    ["弗莱"] = "Fritar",
    ["伦纳德"] = "Leonardo",
    ["罗珊"] = "Rozanne",
    ["没有太大危险了，不用特别在意。"] =
        "Não há mais perigo real, então você não precisa se preocupar.",
    ["罗珊小姐，这个铃铛是用来做什么的？"] =
        "Senhorita Rozanne, para que serve este sino?",
    ["三律之背反"] = "Antinomia das Três Leis",
    ["镜像之自我"] = "Eu espelhado",
    ["技能增强提高<Mark>30</>。"] = "Aprimoramento de habilidade aumentado em <Mark> 30 </> .",
    ["技能增强提高<Mark>30</>。\n激活套装<Mark>灵与知回响</>时不生效。"] =
        "Aprimoramento de habilidade aumentado em <Mark> 30 </> .\nNão tem efeito enquanto o conjunto <Mark> Eco de Espírito e Conhecimento </> estiver ativo.",
    ["<CostRed>{1,2,（烙印已失效）}</>技能增强提高<Mark>30</>。\n激活套装<Mark>灵与知回响</>时不生效。"] =
        "<CostRed> {1,2,(Marca inativa)} </> Aprimoramento de habilidade aumentado em <Mark> 30 </> .\nNão entra em vigor enquanto o conjunto <Mark> Eco de Espírito e Conhecimento </> estiver ativo.",
    ["技能增强提高30。\n激活套装灵与知回响时不生效。"] =
        "Aprimoramento de habilidade aumentado em 30.\nNão entra em vigor enquanto o conjunto Eco do Espírito e Conhecimento estiver ativo.",
}

-- Nearby NPC chat can prepend a channel and translated speaker name to the
-- authored line inside the same widget. Replace only the exact Chinese body
-- and preserve that live prefix.
visibleTextExactOverrides.__translateNearbyConfessionDialogue = function(value)
    for _, replacement in ipairs({
        { "罗、罗茜！你今天过得好吗？", "R-Rosie! How are you today?" },
        { "罗、罗茜！你今天过得好吗?", "R-Rosie! How are you today?" },
        { "啊，弗雷泽！我很好，这束花是……", "Oh, Frazier! I'm doing well. Is that bouquet...?" },
        { "啊，弗雷泽！我很好，这束花是......", "Oh, Frazier! I'm doing well. Is that bouquet...?" },
        { "啊，弗雷泽！我很好，这束花是...", "Oh, Frazier! I'm doing well. Is that bouquet...?" },
        { "我想把它送给你，其实，我对你……", "I wanted to give it to you. Actually, I..." },
        { "我想把它送给你，其实，我对你......", "I wanted to give it to you. Actually, I..." },
        { "我想把它送给你，其实，我对你...", "I wanted to give it to you. Actually, I..." },
    }) do
        local first, last = value:find(replacement[1], 1, true)
        if first ~= nil then
            return value:sub(1, first - 1) .. replacement[2] .. value:sub(last + 1)
        end
    end
    return value
end

-- These current-season material descriptions are delivered outside the
-- reviewed static StringDB corpus. Match the complete semantic signature after
-- removing rich-text tags so wrapping and highlight changes do not bypass the
-- translation.
local function translateSeasonBroochDescription(value)
    if type(value) ~= "string" then
        return value
    end
    local plain = value:gsub("<[^>]+>", "")
    if not plain:find("至多累计至15个。", 1, true) then
        return value
    end
    if plain:find("铸造神话品质胸针（竞技倾向）的关键材料。", 1, true)
        and plain:find("灰雾晶砾", 1, true)
    then
        return "Key material for forging a Mythical-quality brooch (<Highlight>Competitive</>).\n\n"
            .. "Forging consumes <Highlight>15</> Gray Fog Crystal Grit to create an Item Level 64 Mythical-quality brooch (<Highlight>Competitive</>).\n\n"
            .. "As the season progresses, item-level upgrades for Mythical brooches (Competitive) will unlock. Each upgrade consumes a certain amount of Gray Fog Crystal Grit.\n\n"
            .. "Each week, you can obtain up to <Highlight>3</> Gray Fog Crystal Grit directly from Final Hunt, Four-Way League, Hunting City Battle/Highland Battle, and Sustain War with War Treasures. Any unearned amount carries over to the next week, up to a maximum of <Highlight>15</>."
    end
    if plain:find("铸造神话品质胸针（冒险倾向）的关键材料。", 1, true)
        and plain:find("灰雾尘埃", 1, true)
    then
        return "Key material for forging a Mythical-quality brooch (<Highlight>Adventure</>).\n\n"
            .. "Forging consumes <Highlight>15</> Gray Fog Dust to create an Item Level 64 Mythical-quality brooch (<Highlight>Adventure</>).\n\n"
            .. "As the season progresses, item-level upgrades for Mythical brooches (Adventure) will unlock. Each upgrade consumes a certain amount of Gray Fog Dust.\n\n"
            .. "Each week, you can obtain up to <Highlight>3</> Gray Fog Dust directly from Party Dungeons, Team Dungeons, and World Adventure Treasures. Any unearned amount carries over to the next week, up to a maximum of <Highlight>15</>."
    end
    return value
end

local function translateFamilyRecruitmentGuide(value)
    if type(value) ~= "string" then
        return value
    end
    local plain = value:gsub("<[^>]+>", ""):gsub("\r\n", "\n")
    if not plain:find("家族申请表：", 1, true)
        or not plain:find("响应招募：", 1, true)
        or not plain:find("创建家族：", 1, true)
        or not plain:find("加入家族：", 1, true)
    then
        return value
    end

    local expiryDays = plain:find("发布3天后", 1, true) and "3" or "7"
    return "1. <Highlight>Family Application:</> Any Beyonder who has not joined a family can publish a personal application to find a suitable family. The application is automatically withdrawn "
        .. expiryDays .. " days after publication or after successfully joining a family.\n"
        .. "2. <Highlight>Recruitment Response:</> Beyonders who have not joined a family may start a recruitment response or join one started by another Beyonder. The initiator becomes the <Highlight>Family Chief</> by default.\n"
        .. "3. <Highlight>Create Family:</> During the recruitment-response phase, a family can be created once at least <Highlight>3 people</> have responded. During creation, the Chief can adjust the family name and member positions.\n"
        .. "4. <Highlight>Join Family:</> When a family has fewer than <Highlight>14 members</>, the Chief can recruit. Other Beyonders may apply and join directly after the Chief approves their application."
end

-- EquipmentUniqueData descriptions pass through a conditional rich-text
-- formatter before they are painted. Match the complete semantic signature so
-- CostRed/Mark tag variations and the already-formatted plain form take the
-- same reviewed translation path.
visibleTextExactOverrides.__translateEquipmentSpecialText = function(value)
    if type(value) ~= "string" then
        return value
    end
    local plain = value:gsub("<[^>]+>", ""):gsub("\r\n", "\n")
    if not plain:find("激活套装灵与知回响时不生效。", 1, true) then
        return value
    end

    local prefix = ""
    if value:find("<CostRed>", 1, true) then
        prefix = "<CostRed>{1,2,(Brand inactive)}</>"
    end
    local inactive = "\nDoes not take effect while the <Mark>Echo of Spirit and Knowledge</> set is active."

    if plain:find("技能增强提高30。", 1, true) then
        return prefix .. "Skill Enhancement increased by <Mark>30</>." .. inactive
    end
    if plain:find("释放解控技能后，获得50点技能抵挡", 1, true)
        and plain:find("每30秒最多触发一次。", 1, true)
    then
        return prefix
            .. "After using a Cleanse Skill, gain <Mark>50</> Skill Block for <Mark>10</> seconds. "
            .. "Can trigger at most once every <Mark>30</> seconds."
            .. inactive
    end
    if plain:find("破防提高80。", 1, true)
        and plain:find("获得60点防御", 1, true)
        and plain:find("每10秒最多触发一次。", 1, true)
    then
        return prefix
            .. "Armor Break increased by <Mark>80</>. When taking damage, there is a chance to gain "
            .. "<Mark>60</> Defense for <Mark>5</> seconds. Can trigger at most once every <Mark>10</> seconds."
            .. inactive
    end
    return value
end

-- Sealed Artifact descriptions are evaluated before display, so CheckStar
-- expressions become live numbers and no longer match the source template.
-- Rebuild the complete reviewed text from its semantic fields while retaining
-- every evaluated value supplied by the game.
visibleTextExactOverrides.__translateLifeStaffDetails = function(value)
    if type(value) ~= "string" then
        return value
    end
    local plain = value:gsub("<[^>]+>", ""):gsub("\r\n", "\n")
    if not plain:find("生命能量", 1, true)
        or not plain:find("蓬勃生长", 1, true)
        or not plain:find("生命之种", 1, true)
        or not plain:find("累计有效治疗", 1, true)
    then
        return value
    end

    local interval = plain:match("每隔([%d%.,]+)秒")
    local energyLimit = plain:match("持有上限为([%d%.,]+)点")
    local healingThreshold = plain:match("生命值上限的([%d%.,]+)%%")
    local growthStacks = plain:match("附加([%d%.,]+)层")
    local growthDuration = plain:match("蓬勃生长.-持续([%d%.,]+)秒")
    local seedLimit = plain:match("生命之种.-持有上限为([%d%.,]+)枚")
    local growthLine = plain:match("蓬勃生长：([^\n]+)") or ""
    local healingAmount = growthLine:match("恢复([%d%.,]+)点生命值")
    local seedLine = plain:match("生命之种：([^\n]+)") or ""
    local lowHealthThreshold = seedLine:match("生命值低于([%d%.,]+)%%")
    local seedRecovery = seedLine:match("固定恢复([%d%.,]+)%%上限")
    if interval == nil or energyLimit == nil or healingThreshold == nil
        or growthStacks == nil or growthDuration == nil or seedLimit == nil
        or healingAmount == nil or lowHealthThreshold == nil or seedRecovery == nil
    then
        return value
    end

    local translated = "<Yellow>Life Energy</>: The bearer gains 1 Life Energy every <Yellow>"
        .. interval .. " seconds</>, up to <Yellow>" .. energyLimit .. "</>. When the bearer's cumulative "
        .. "effective healing to themself or an ally exceeds <Yellow>" .. healingThreshold
        .. "%</> of the bearer's maximum HP, 1 Life Energy is consumed to apply <Yellow>"
        .. growthStacks .. "</> stacks of <Yellow>Flourishing Growth</> to the target for <Yellow>"
        .. growthDuration .. " seconds</>. The bearer also gains 1 <Yellow>Seed of Life</>, up to <Yellow>"
        .. seedLimit .. "</>.\n\n<Yellow>Flourishing Growth</>: While HP is not full, consumes 1 stack "
        .. "per second to restore <Yellow>" .. healingAmount .. "</> HP.\n<Yellow>Seed of Life</>: "
        .. "When the bearer takes damage below <Yellow>" .. lowHealthThreshold
        .. "%</> HP, automatically consumes 1 Seed of Life to restore <Yellow>"
        .. seedRecovery .. "%</> of maximum HP."
    if plain:find("主宰争锋", 1, true) then
        translated = translated
            .. "\nWhile in Dominator's Clash, Life Staff effects are reduced."
    end
    return translated
end

local visibleTextReplacements = {
    {
        "绯红月辉？难道是这张红月纸牌？用它试试。",
        "Luar carmesim? Poderia ser esta carta da Lua Vermelha? Vamos tentar.",
    },
    { "点击空白区域关闭", "Clique na área em branco para fechar" },
    { "跳过", "Pular" },
    { "推荐非凡评分", "Classificação recomendada Beyonder" },
    { "非凡评分", "Beyonder Avaliação" },
    { "塞巴斯蒂安", "Sebastião" },
    { "寒巴斯蒂安", "Sebastião" },
    { "男子：", "Homem:" },
    { "丑人：", "Homem feio:" },
    { "“愚者”：", "\"O Louco\":" },
    { "愚者", "O tolo" },
    { "（癫狂）", "(Manicamente)" },
    { "万物的“母亲”", "\"Mãe\" de todas as coisas" },
    { "赐予我们新生", "conceda-nos o renascimento" },
    { "拿上这个", "Pegue isso" },
    { "有效期十四年？为什么要签这么久的合同……", "Válido por quatorze anos? Por que eu precisaria assinar um contrato tão longo..." },
    {
        "感知灵界，观测星空，通过灵性物品启示的命运变化，解读其映射的现实空间异动、事态发展走向与潜在未知危险。",
        "Sinta o mundo espiritual e observe as estrelas. Interprete as mudanças no destino reveladas pelos itens espirituais para discernir os distúrbios do mundo real que eles refletem, como os eventos podem se desenrolar e os perigos potenciais desconhecidos.",
    },
    {
        "占星启示期间，周围的玩家可以获得临时技能来获取占星指引。",
        "Durante a Revelação Astrológica, jogadores próximos podem ganhar uma habilidade temporária para receber orientação astrológica.",
    },
    {
        "使自身获得武力加4，直觉加2。使用临时技能获取占星指引的玩家也可以获得武力加4，直觉加2。",
        "Ganhe +4 de Força e +2 de Intuição. Os jogadores que usam a habilidade temporária para receber orientação astrológica também ganham +4 de Força e +2 de Intuição.",
    },
}

-- Exact localization keys from build 1.2018737.2044036. These repair rows
-- that were evaluated before the translated StringDB partitions were ready.
local marionetteSkillLocalization = {
    [87303001] = { 286217962784256, 286218768090624, 286218231219712, 514572247120128 },
    [87303002] = { 286217962784512, 286218768090880, 286218231219968, 514572247120128 },
    [87303003] = { 286217962784256, 286218768090624, nil, 514572247120128 },
    [87303004] = { 286217962785024, 286218768091392, 286218231220480, 286219304962304 },
    [87303010] = { 286217962786048, 286218768092416, 286218231221504, 286219304963328 },
    [87303020] = { 286217962786560, 286218768092928, 286218231222016, 286219304963840 },
    [87303030] = { 286217962787840, 286218768094208, 286218231223296, 286219304965120 },
    [87303040] = { 286217962791168, 286218768097536, 286218231226624, 1240250726755840 },
    [87303050] = { 998771022366208, 286218768099840, 286218231228928, 286219304970752 },
    [87303060] = { 286217962794240, 286218768100608, 286218231229696, 286219304971520 },
    [87303070] = { 286217962795264, 286218768101632, 286218231230720, 514572247120128 },
    [87303071] = { 286217962795776 },
    [87303072] = { 286217962796032 },
    [87303080] = { 286217962796288, 286218768102656, 286218231231744, 286219304965120 },
    [87303090] = { 286217962797824, 286218768104192, 286218231233280, 286219304975104 },
    [87303100] = { 286217962798848, 286218231234304, 286218231234304, 514572247120128 },
    [87303110] = { 286217962799360, 286218768105728, 286218231234816, 202518445427712 },
    [87303120] = { 286217962799872, 286218768106240, 286218231235328, 294670189988096 },
    [87303130] = { 286217962800384, 286218768106752, 286218231235840, 286219304977664 },
    [87303140] = { 286217962801152, 286218768107520, 286218231236608, 286219304970752 },
    [87303150] = { 286217962802688, 286218768109056, 286218231238144, 294670189993984 },
    [87303160] = { 998771022396928, 286218768109824, 286218231238912, 286219304980736 },
    [87303170] = { 998771022409216, 286218768110848, 286218231239936, 286219304971520 },
    [87303180] = { 286217962805504, 286218768111872, 286218231240960 },
    [87303190] = { 286217962806016, 286218768112384, 286218231241472 },
    [87303200] = { 998771022398464, 286218768112896, 286218231241984, 286219304965120 },
    [87303210] = { 998771022400000, 286218768113664, 286218231242752, 286219304971520 },
    [87303220] = { 286217962787840, 286218768094208, 286218231223296, 286219304965120 },
    [87303300] = { 286217962808064, 286218768114432, 286218231243520, 294670189988352 },
    [87303310] = { 286217962808576, 286218768114944, 286218231244032, 294670189988096 },
    [87303320] = { 286217962809344, 286218768115712, 286218231244800, 286219304971520 },
    [87303330] = { 286217962810368, 286218768116736, 286218231245824, 286219304971520 },
    [87303340] = { 286217962811136, 286218768117504, 286218231246592, 286219304988416 },
    [87303350] = { 286217962811648, 286218768118016, 286218231247104, 294670189988864 },
    [87303360] = { 286217962812160, 286218768118528, 286218231247616, 1240250995202816 },
    [87303370] = { 286217962812928, 286218768119296, 286218231248384, 286219304970752 },
    [87303380] = { 286217962813440, 286218768119808, 286218231248896, 255362649299968 },
    [87303390] = { 286217962813952, 286218768120320, 286218231249408, 286219304965120 },
    [87303400] = { 286217962814464, 286218768120832, 286218231249920, 282026343139328 },
    [87303410] = { 286217962814976, 286218768121344, 286218231250432, 514572247120128 },
    [87303420] = { 286217962815744, 286218768122112, 286218231251200, 514572247120128 },
    [87303430] = { 286217962816256, 286218768122624, 286218231251712, 514572247120128 },
    [87303440] = { 286217962816768, 286218768123136, 286218231252224, 514572247120128 },
}

local marionetteEnglishNames = {
    [87303350] = "Chegada do amanhecer",
    [87303360] = "Marca de Arbitragem",
    [87303370] = "Olhar misterioso",
    [87303380] = "Proteção contra luz matinal",
    [87303390] = "Juramento do Cavaleiro",
    [87303400] = "Possessão do Espírito Borboleta",
    [87303410] = "Sombra Descendente",
    [87303420] = "Eco da Sentença de Morte",
    [87303430] = "Combinação de garras de lobo alfa",
    [87303440] = "Proteção de perfuração",
}

local marionetteSkillIdByIconNumber = {
    [14] = 87303410,
    [20] = 87303350,
    [21] = 87303360,
    [22] = 87303370,
    [23] = 87303380,
    [24] = 87303390,
    [25] = 87303400,
    [31] = 87303420,
    [32] = 87303430,
    [33] = 87303440,
}

local shortMenuLabels = {
    Fashion = "Estilo",
    Pastime = "Explorar",
    Dungeon = "Masmorra",
    PVP = "Arena",
    Equip = "Equipamento",
    Skill = "Habilidades",
    Talent = "Talento",
    Promotion = "Caminho",
    Sealed = "Relíquias",
    SecretPartner = "Fantoches",
    Fellow = "Aliados",
    Paotuan = "TRPG",
    Guild = "Clube",
    Home = "Castelo",
    Task = "Missões",
    Family = "Família",
    Qingyuan = "Títulos",
    Achievement = "Prêmios",
    Strategy = "Guia",
    VideoCreation = "Criador",
    Friend = "Amigos",
    ShadowCity = "Cidade Negra",
    Character = "Perfil",
    HomePage = "Lar",
    Bag = "Bolsa",
    Notice = "Notícias",
    Email = "Correspondência",
    Rank = "Classificação",
    Detach = "Desequipar",
    Setting = "Configurações",
    QuitGame = "Saída",
}

local directTables = {}
local MISSING_DIRECT_TABLE = {}
local function report(message)
    local logger = Log or LaunchLog
    if logger and logger.Info then
        logger.Info("[CPDDRuntimeFix] " .. tostring(message))
    end
end

local runtimeMetrics = {
    GeminiLoads = 0,
    SourceShardLoads = 0,
    SourceShardHits = 0,
    SourceShardMisses = 0,
    TranslationCacheHits = 0,
    TranslationCacheMisses = 0,
    LiveRepairCacheHits = 0,
    LiveRepairCacheMisses = 0,
    WidgetIndexesBuilt = 0,
    GetAllWidgetsCalls = 0,
    WidgetsVisited = 0,
    PanelsRepaired = 0,
    PanelRepairMillis = 0,
    PanelLabelsRepaired = 0,
    PanelRepairReportsSuppressed = 0,
    KsbcFallbacks = 0,
    UnresolvedVisibleCjk = 0,
    UnresolvedCjkWrites = 0,
    UnresolvedCjkWriteFailures = 0,
    CaptureDataAssignmentsEnabled = false,
}
local runtimeFixes = {}
Loader.Telemetry = Loader.Telemetry or {}
Loader.Telemetry.Runtime = runtimeMetrics

local function nowMilliseconds()
    if os and type(os.clock) == "function" then
        return os.clock() * 1000
    end
    return 0
end

local function runtimeRowRepairEnabled()
    local loader = rawget(_G, "LOMModLoader")
    local features = loader and loader.Features
    if type(features) ~= "table" then
        return true
    end
    return features.RuntimeRowRepair ~= false
end

local function setRuntimeRowRepair(enabled)
    local loader = rawget(_G, "LOMModLoader")
    if loader == nil then
        loader = { Features = {} }
        rawset(_G, "LOMModLoader", loader)
    elseif type(loader.Features) ~= "table" then
        loader.Features = {}
    end
    loader.Features.RuntimeRowRepair = enabled == true
    return loader.Features.RuntimeRowRepair
end

local function runtimeUIRepairEnabled()
    local loader = rawget(_G, "LOMModLoader")
    local features = loader and loader.Features
    if type(features) ~= "table" then
        return true
    end
    return features.RuntimeUIRepair ~= false
end

local function setRuntimeUIRepair(enabled)
    local loader = rawget(_G, "LOMModLoader")
    if loader == nil then
        loader = { Features = {} }
        rawset(_G, "LOMModLoader", loader)
    elseif type(loader.Features) ~= "table" then
        loader.Features = {}
    end
    loader.Features.RuntimeUIRepair = enabled == true
    return loader.Features.RuntimeUIRepair
end

local geminiTextOverrides = nil
local geminiTextUnavailable = false

local function lookupGeminiText(value)
    if geminiTextOverrides == nil and not geminiTextUnavailable then
        local ok, loaded = pcall(require, "mods.cpdd_runtime_fixes.RuntimeTextGemini")
        if ok and type(loaded) == "table" then
            geminiTextOverrides = loaded
            runtimeMetrics.GeminiLoads = runtimeMetrics.GeminiLoads + 1
        else
            geminiTextUnavailable = true
            report("Gemini runtime text map unavailable: " .. tostring(loaded))
        end
    end
    return geminiTextOverrides and geminiTextOverrides[value] or nil
end

-- TextControlSentenceData uses #CanMove...# as executable puzzle markup, not
-- decoration. Translate the visible word inside each marker, but never let a
-- reviewed whole-string translation remove the marker or make it disagree
-- with the separately translated `word` field used to validate the answer.
local function preserveMovableAnswerMarkup(source, translated)
    if type(source) ~= "string" or type(translated) ~= "string"
        or not source:find("#CanMove", 1, true)
    then
        return translated
    end

    local answers = {}
    for inner in source:gmatch("#CanMove(.-)#") do
        local innerTranslation = lookupGeminiText(inner)
        if type(innerTranslation) ~= "string" or innerTranslation == "" then
            innerTranslation = inner
        end
        answers[#answers + 1] = innerTranslation
    end
    if #answers == 0 then
        return translated
    end

    local markerIndex = 0
    local repaired, markerCount = translated:gsub("#CanMove.-#", function()
        markerIndex = markerIndex + 1
        return "#CanMove" .. (answers[markerIndex] or answers[#answers]) .. "#"
    end)
    if markerCount == #answers then
        return repaired
    end

    if #answers == 1 and source:match("^#CanMove.-#$") then
        return "#CanMove" .. answers[1] .. "#"
    end

    -- A few contextual translations moved the answer within the English
    -- sentence while dropping its marker. Locate the translated answer in the
    -- reviewed sentence and restore the control tag around that exact span.
    if #answers == 1 then
        local haystack = translated:lower():gsub("grey", "gray")
        local needle = answers[1]:lower():gsub("grey", "gray")
        local first, last = haystack:find(needle, 1, true)
        if first ~= nil then
            return translated:sub(1, first - 1)
                .. "#CanMove" .. answers[1] .. "#"
                .. translated:sub(last + 1)
        end
    end
    return translated
end

local function getSymbol(value, environment, name)
    if type(value) == "table" and value[name] ~= nil then
        return value[name]
    end
    if type(environment) == "table" and environment[name] ~= nil then
        return environment[name]
    end
    return rawget(_G, name)
end

-- Generated Lua views expose only widgets marked as Blueprint variables. The
-- game still contains several important text blocks (including dialogue row 3)
-- that are present in the UWidgetTree but intentionally omitted from that
-- generated view. Resolve both forms, plus the WidgetTree API used by a few
-- older panels.
local widgetLists = setmetatable({}, { __mode = "k" })
local widgetNameIndexes = setmetatable({}, { __mode = "k" })
local NO_WIDGET_LIST = {}

-- Native UWidgetTree enumeration is build-dependent: some C7 builds accept a
-- Lua table as the out array, while others require a typed slua.Array.  The
-- latter was the missing discovery path for cooked Blueprint-only labels.
local unrealArrayTypes = {
    Resolved = false,
    PropertyClass = nil,
    WidgetClass = nil,
}

local function resolveUnrealArrayTypes()
    if unrealArrayTypes.Resolved
        and unrealArrayTypes.PropertyClass ~= nil
        and unrealArrayTypes.WidgetClass ~= nil
    then
        return
    end
    unrealArrayTypes.Resolved = true
    if unrealArrayTypes.PropertyClass == nil then
        pcall(function() unrealArrayTypes.PropertyClass = import("EPropertyClass") end)
    end
    if unrealArrayTypes.WidgetClass == nil then
        pcall(function() unrealArrayTypes.WidgetClass = import("Widget") end)
    end
    if unrealArrayTypes.WidgetClass == nil and slua and type(slua.loadClass) == "function" then
        pcall(function()
            unrealArrayTypes.WidgetClass = slua.loadClass("/Script/UMG.Widget")
        end)
    end
end

local function newWidgetObjectArray()
    resolveUnrealArrayTypes()
    if not slua or type(slua.Array) ~= "function"
        or unrealArrayTypes.PropertyClass == nil
        or unrealArrayTypes.WidgetClass == nil
    then
        return nil
    end
    local ok, output = pcall(
        slua.Array,
        unrealArrayTypes.PropertyClass.Object,
        unrealArrayTypes.WidgetClass
    )
    return ok and output or nil
end

local function unrealArrayToTable(value)
    if type(value) == "table" then return value end
    if value and type(value.ToTable) == "function" then
        local ok, result = pcall(value.ToTable, value)
        if ok and type(result) == "table" then return result end
    end
    if value and type(value.Num) == "function" and type(value.Get) == "function" then
        local output = {}
        local countOk, count = pcall(value.Num, value)
        if countOk and type(count) == "number" then
            for index = 0, count - 1 do
                local itemOk, item = pcall(value.Get, value, index)
                if itemOk and item ~= nil then output[#output + 1] = item end
            end
        end
        return output
    end
    return {}
end

local function invalidateWidgetCache(owner)
    if owner ~= nil then
        widgetLists[owner] = nil
        widgetNameIndexes[owner] = nil
    end
end

local function getWidgetList(owner)
    if owner == nil then
        return nil
    end
    local cached = widgetLists[owner]
    if cached ~= nil then
        return cached ~= NO_WIDGET_LIST and cached or nil
    end

    -- Most owners reached by the recursive walk are leaf widgets. Resolve the
    -- tree before allocating an Unreal object array so leaf visits stay cheap.
    local tree = nil
    local getAllWidgets = nil
    local treeOk = pcall(function()
        tree = owner.WidgetTree
        getAllWidgets = tree and tree.GetAllWidgets or nil
    end)
    if not treeOk or tree == nil or type(getAllWidgets) ~= "function" then
        widgetLists[owner] = NO_WIDGET_LIST
        return nil
    end

    local widgets = newWidgetObjectArray() or {}
    local ok, result = pcall(function()
        runtimeMetrics.GetAllWidgetsCalls = runtimeMetrics.GetAllWidgetsCalls + 1
        return getAllWidgets(tree, widgets)
    end)
    if not ok then
        widgetLists[owner] = NO_WIDGET_LIST
        return nil
    end
    widgets = unrealArrayToTable(result ~= nil and result or widgets)
    widgetLists[owner] = widgets
    runtimeMetrics.WidgetIndexesBuilt = runtimeMetrics.WidgetIndexesBuilt + 1
    return widgets
end

local function getWidgetNameIndex(owner)
    local cached = widgetNameIndexes[owner]
    if cached ~= nil then
        return cached
    end
    local index = {}
    for _, candidate in pairs(getWidgetList(owner) or {}) do
        local candidateName = nil
        pcall(function()
            if candidate ~= nil and candidate.GetName ~= nil then
                candidateName = tostring(candidate:GetName())
            end
        end)
        if candidateName ~= nil and index[candidateName] == nil then
            index[candidateName] = candidate
        end
    end
    widgetNameIndexes[owner] = index
    return index
end

local function getNamedWidget(owner, name)
    if owner == nil or type(name) ~= "string" then
        return nil
    end

    local widget = nil
    pcall(function()
        widget = owner[name]
    end)
    if widget ~= nil then
        return widget
    end

    pcall(function()
        if owner.GetWidgetFromName ~= nil then
            widget = owner:GetWidgetFromName(name)
        end
    end)
    if widget ~= nil then
        return widget
    end

    pcall(function()
        local tree = owner.WidgetTree
        if tree ~= nil then
            if tree.FindWidget ~= nil then
                widget = tree:FindWidget(name)
            elseif tree.GetWidgetFromName ~= nil then
                widget = tree:GetWidgetFromName(name)
            end
        end
    end)
    if widget ~= nil then
        return widget
    end

    -- Several cooked UserWidgets keep static Blueprint variables out of both
    -- the generated Lua view and FindWidget/GetWidgetFromName. GetAllWidgets
    -- still exposes them. This is the path used by the third dialogue row and
    -- by embedded copies of the Improve header in Talent/Artifact screens.
    return getWidgetNameIndex(owner)[name]
end

local repairLiveString
local hasCjk
-- Development builds replace this no-op inside the stripped JSONL block.
-- Keeping the callable in production lets the targeted repair remain free of
-- development-only branches and private logging state.
runtimeMetrics.CaptureDataAssignment = function() return false end
runtimeMetrics.CaptureTranslationAssignment = function(...) return runtimeMetrics.CaptureDataAssignment(...) end
local visibleTextCache = {}

local function walkWidgetDescendants(owner, visited, visitor)
    if owner == nil or visited[owner] then
        return
    end
    visited[owner] = true
    runtimeMetrics.WidgetsVisited = runtimeMetrics.WidgetsVisited + 1
    visitor(owner)

    -- Cooked Blueprint variables can be absent from both the generated Lua
    -- view and WidgetTree lookups. Their parent panel is still exposed, and
    -- UPanelWidget child traversal reaches the actual painted text blocks.
    local count = nil
    pcall(function()
        if owner.GetChildrenCount ~= nil then
            count = tonumber(owner:GetChildrenCount())
        end
    end)
    if count ~= nil then
        for index = 0, count - 1 do
            local child = nil
            pcall(function()
                child = owner:GetChildAt(index)
            end)
            walkWidgetDescendants(child, visited, visitor)
        end
    end

    local content = nil
    pcall(function()
        if owner.GetContent ~= nil then
            content = owner:GetContent()
        end
    end)
    walkWidgetDescendants(content, visited, visitor)

    -- ListView and TileView rows are virtualized UUserWidgets. They are not
    -- children of the owning panel's WidgetTree, so text in a displayed item
    -- tooltip can be painted while remaining invisible to the normal tree
    -- walk. Follow only the entries that Unreal currently has on screen; this
    -- is bounded by the viewport and does not enumerate every live widget.
    local getDisplayedEntries = nil
    pcall(function() getDisplayedEntries = owner.GetDisplayedEntryWidgets end)
    if type(getDisplayedEntries) == "function" then
        local displayedEntries = {}
        local displayedOk, displayedResult = pcall(
            getDisplayedEntries,
            owner,
            displayedEntries
        )
        if displayedOk then
            local entries = type(displayedResult) == "table" and displayedResult or displayedEntries
            for _, entry in pairs(entries) do
                walkWidgetDescendants(entry, visited, visitor)
            end
        end
    end

    for _, widget in pairs(getWidgetList(owner) or {}) do
        walkWidgetDescendants(widget, visited, visitor)
    end
end

local function translateVisibleText(value)
    if type(value) ~= "string" then
        return value
    end

    local cached = visibleTextCache[value]
    if cached ~= nil then
        runtimeMetrics.TranslationCacheHits = runtimeMetrics.TranslationCacheHits + 1
        return cached
    end
    runtimeMetrics.TranslationCacheMisses = runtimeMetrics.TranslationCacheMisses + 1
    local enterWorldShortened = shortenEnterWorldLabel(value)
    if enterWorldShortened ~= value then
        visibleTextCache[value] = enterWorldShortened
        return enterWorldShortened
    end
    local questPasswordRestored = restoreQuestChatPassword(value)
    if questPasswordRestored ~= value then
        visibleTextCache[value] = questPasswordRestored
        return questPasswordRestored
    end
    local reviewedExact = visibleTextExactOverrides[value]
    if reviewedExact ~= nil then
        visibleTextCache[value] = reviewedExact
        return reviewedExact
    end
    if hasCjk and not hasCjk(value) then
        visibleTextCache[value] = value
        return value
    end

    local confessionDialogue = visibleTextExactOverrides.__translateNearbyConfessionDialogue(value)
    if confessionDialogue ~= value then
        visibleTextCache[value] = confessionDialogue
        return confessionDialogue
    end

    local familyGuide = translateFamilyRecruitmentGuide(value)
    if familyGuide ~= value then
        visibleTextCache[value] = familyGuide
        return familyGuide
    end

    local broochDescription = translateSeasonBroochDescription(value)
    if broochDescription ~= value then
        visibleTextCache[value] = broochDescription
        return broochDescription
    end

    local equipmentSpecialText = visibleTextExactOverrides.__translateEquipmentSpecialText(value)
    if equipmentSpecialText ~= value then
        visibleTextCache[value] = equipmentSpecialText
        return equipmentSpecialText
    end

    local lifeStaffDetails = visibleTextExactOverrides.__translateLifeStaffDetails(value)
    if lifeStaffDetails ~= value then
        visibleTextCache[value] = lifeStaffDetails
        return lifeStaffDetails
    end

    local voiceChatCount = value:match("^<GreenVoice>(%d+)</>人连麦中%.%.%.$")
        or value:match("^<GreenVoice>(%d+)</>人连麦中……$")
    if voiceChatCount ~= nil then
        local result = "<GreenVoice>" .. voiceChatCount .. "</> people in voice chat..."
        visibleTextCache[value] = result
        return result
    end

    local obtainableQuantity = value:match("^可获得数量：(%d+)$")
        or value:match("^可获得数量:(%d+)$")
    if obtainableQuantity ~= nil then
        local result = "Obtainable Quantity: " .. obtainableQuantity
        visibleTextCache[value] = result
        return result
    end

    local newMessageCount = value:match("^新消息(%d+)条$")
    if newMessageCount ~= nil then
        local result = newMessageCount .. " new messages"
        visibleTextCache[value] = result
        return result
    end

    local aggregateCount = value:match("^本次一键聚合累计聚合(%d+)次，共消耗$")
    if aggregateCount ~= nil then
        local result = "This one-click aggregation performed " .. aggregateCount
            .. " merges in total, consuming"
        visibleTextCache[value] = result
        return result
    end

    local probabilityRate = value:match("^概率(<Rate>.-</>)$")
    if probabilityRate ~= nil then
        local result = "Probability " .. probabilityRate
        visibleTextCache[value] = result
        return result
    end

    local fashionValue = value:match("^风尚值：(%d+)$")
        or value:match("^风尚值:(%d+)$")
    if fashionValue ~= nil then
        local result = "Fashion Value: " .. fashionValue
        visibleTextCache[value] = result
        return result
    end

    local ratingValue = value:match("^非凡评分%s*([%d].*)$")
    if ratingValue ~= nil then
        local result = "Beyonder Rating " .. ratingValue
        visibleTextCache[value] = result
        return result
    end

    local shieldCurrent, shieldMaximum = value:match("^米尔贡根之盾%((%d+)/(%d+)%)$")
    if shieldCurrent ~= nil then
        local result = "Milgongen's Shield (" .. shieldCurrent .. "/" .. shieldMaximum .. ")"
        visibleTextCache[value] = result
        return result
    end

    local mergeCurrent, mergeMaximum = value:match("^选择需要聚合的非凡物质(%d+)/(%d+)$")
    if mergeCurrent ~= nil then
        local result = "Select Beyonder Materials to Merge " .. mergeCurrent .. "/" .. mergeMaximum
        visibleTextCache[value] = result
        return result
    end

    local distributionTime = value:match("^分配中(<Time>.-</>)$")
    if distributionTime ~= nil then
        local result = "Distributing " .. distributionTime
        visibleTextCache[value] = result
        return result
    end

    local recollectionLevel = value:match("^回想(%d+)级$")
    if recollectionLevel ~= nil then
        local result = "Recollection Lv. " .. recollectionLevel
        visibleTextCache[value] = result
        return result
    end

    local awakeningLevel = value:match("^觉醒等级Lv(%d+)$")
    if awakeningLevel ~= nil then
        local result = "Awakening Lv. " .. awakeningLevel
        visibleTextCache[value] = result
        return result
    end

    local unlockDays, unlockHours, unlockMinutes = value:match(
        "^解冻剩余时间：(%d+)天(%d+)小时(%d+)分$"
    )
    if unlockDays ~= nil then
        local result = "Time until unlocked: " .. unlockDays .. "d "
            .. unlockHours .. "h " .. unlockMinutes .. "m"
        visibleTextCache[value] = result
        return result
    end

    local dailyRefreshHour = value:match("^每日(%d+)点自动刷新$")
    if dailyRefreshHour ~= nil then
        local result = "Refreshes daily at " .. dailyRefreshHour .. ":00"
        visibleTextCache[value] = result
        return result
    end

    local noticeHours, noticeMinutes = value:match("^公示期(%d+)小时(%d+)分$")
    if noticeHours ~= nil then
        local result = "Listing period: " .. noticeHours .. "h " .. noticeMinutes .. "m"
        visibleTextCache[value] = result
        return result
    end

    local countdownHours, countdownMinutes = value:match(
        "^公示期倒计时：(%d+)小时(%d+)分钟$"
    )
    if countdownHours ~= nil then
        local result = "Listing period remaining: " .. countdownHours
            .. "h " .. countdownMinutes .. "m"
        visibleTextCache[value] = result
        return result
    end

    local historyPoints = value:match("^达成奖励：获得历史研究积分%+(%d+)$")
    if historyPoints ~= nil then
        local result = "Completion Reward: Historical Research Points +" .. historyPoints
        visibleTextCache[value] = result
        return result
    end

    local stackCount = value:match("^(%d+)层$")
    if stackCount ~= nil then
        local result = "Stack " .. stackCount
        visibleTextCache[value] = result
        return result
    end

    local selectedCount, selectedMaximum = value:match(
        "^当前已选择%s*<Yellow>(%d+)</>/(%d+)$"
    )
    if selectedCount ~= nil then
        local result = "Selected <Yellow>" .. selectedCount .. "</>/" .. selectedMaximum
        visibleTextCache[value] = result
        return result
    end

    if value:find("【半神】", 1, true) == 1 and value:find("真神：序列0", 1, true) then
        local result = "[Demigod]\n"
            .. "Description: A collective term for Saints and Angels from Sequence 4 through Sequence 1. "
            .. "Their life and spirit undergo a qualitative transformation, they gain 50% divinity, and their abilities transcend the human realm. "
            .. "Demigods can continue advancing toward True Godhood. Demigods are further divided into Saints and Angels; Sequence 0, above Sequence 1, is known as a True God.\n"
            .. "True God: Sequence 0, possessing a complete Mythical Creature form.\n"
            .. "Location: Open Menu - Sequence to advance.\n"
            .. "Related: Character Development - Improve"
        visibleTextCache[value] = result
        return result
    end

    local interval, damage, slowPercent, duration = value:match(
        "^在目标位置召唤窥秘之眼链接目标，每([%d%.]+)秒对目标造成([%d%.]+)伤害并使目标减速([%d%.]+)%%。链接最多持续([%d%.]+)秒，目标远离窥秘之眼一定距离后链接会提前断开。$"
    )
    if interval ~= nil then
        local result = "Summon an Eye of Mystery at the target location to link to the target, dealing "
            .. damage .. " damage every " .. interval .. " seconds and slowing the target by "
            .. slowPercent .. "%. The link lasts up to " .. duration
            .. " seconds and breaks early if the target moves too far from the Eye of Mystery."
        visibleTextCache[value] = result
        return result
    end

    local gemini = lookupGeminiText(value)
    if gemini ~= nil then
        gemini = preserveMovableAnswerMarkup(value, gemini)
        visibleTextCache[value] = gemini
        return gemini
    end

    local result = value
    for _, replacement in ipairs(visibleTextReplacements) do
        result = result:gsub(replacement[1], function()
            return replacement[2]
        end)
    end
    visibleTextCache[value] = result
    return result
end

local function translateTextWidget(widget, discoveryContext)
    if widget == nil then
        return 0
    end

    local ok, current = pcall(function()
        return widget:GetText()
    end)
    if not ok or current == nil then
        return 0
    end

    local currentText = type(current) == "string" and current or tostring(current)
    local widgetName = "Text"
    pcall(function()
        widgetName = tostring(widget:GetName())
    end)
    local translated = repairLiveString and repairLiveString("WidgetText", widgetName, widgetName, currentText)
        or translateVisibleText(currentText)
    local repairedCount = 0
    if translated ~= currentText then
        local changed = pcall(function()
            widget:SetText(translated)
        end)
        -- KGTextBlock can repaint its serialized Text property after a
        -- Blueprint state change. Keep the property and Slate value aligned.
        pcall(function()
            widget.Text = translated
        end)
        pcall(function()
            if widget.SynchronizeProperties ~= nil then
                widget:SynchronizeProperties()
            end
        end)
        pcall(function()
            if widget.InvalidateLayoutAndVolatility ~= nil then
                widget:InvalidateLayoutAndVolatility()
            end
        end)
        repairedCount = changed and 1 or 0
    end
        return repairedCount
end

-- The reference translation runtime generates a global list of text-like
-- Blueprint variable names and probes them through UIFunctionLibrary.FindWidget.
-- That reaches cooked widgets which are absent from both the Lua view and the
-- owning UWidgetTree.  Probe in small timer batches so full coverage does not
-- create a single-frame UI hitch.
local criticalWidgetProbeNames = {
    "Text_Use", "Text_Used", "TextUsing", "Text_State", "Text_Status",
    "Text_Apply", "Text_Equip", "RichText_Use", "Button_Text",
    "Text_Name", "Text_Title", "Text_Content", "Text_Tips", "Text_BtnName",
}
local generatedWidgetProbeNames = nil
local generatedWidgetProbeUnavailable = false
local widgetProbeStates = setmetatable({}, { __mode = "k" })
local widgetProbeLibrary = nil
local WIDGET_PROBE_BATCH_SIZE = 192

local function loadGeneratedWidgetProbeNames()
    if generatedWidgetProbeNames ~= nil then return generatedWidgetProbeNames end
    local output, seen = {}, {}
    local function append(name)
        if type(name) == "string" and name ~= "" and not seen[name] then
            seen[name] = true
            output[#output + 1] = name
        end
    end
    for _, name in ipairs(criticalWidgetProbeNames) do append(name) end
    if not generatedWidgetProbeUnavailable then
        local ok, names = pcall(require, "mods.cpdd_runtime_fixes.WidgetNameIndex")
        if ok and type(names) == "table" then
            for _, name in ipairs(names) do append(name) end
        else
            generatedWidgetProbeUnavailable = true
            report("generated widget-name index unavailable: " .. tostring(names))
        end
    end
    generatedWidgetProbeNames = output
    return output
end

local function resolveWidgetProbeLibrary()
    if widgetProbeLibrary and widgetProbeLibrary ~= false then return widgetProbeLibrary end
    local ok, value = pcall(import, "UIFunctionLibrary")
    widgetProbeLibrary = ok and value or false
    return widgetProbeLibrary or nil
end

local function scheduleWidgetProbe(component, callback)
    local owners = { component, Game and Game.NewUIManager }
    for _, owner in ipairs(owners) do
        local ok, addTimer = pcall(function() return owner and owner.AddTimerWithFunction end)
        if ok and type(addTimer) == "function"
            and pcall(addTimer, owner, 0.01, 1, callback)
        then
            return true
        end
    end
    return false
end

local function queueGeneratedWidgetProbe(rootWidget, component, discoveryContext)
    if rootWidget == nil then return end
    local library = resolveWidgetProbeLibrary()
    local findWidget = library and library.FindWidget
    if type(findWidget) ~= "function" then return end

    local state = widgetProbeStates[rootWidget]
    if state == nil then
        state = {
            NextIndex = 1,
            Pending = false,
            Complete = false,
            HitNames = {},
            Visited = setmetatable({}, { __mode = "k" }),
        }
        widgetProbeStates[rootWidget] = state
    end

    -- Dynamic Blueprint state changes can restore serialized Chinese after the
    -- initial probe. Revisit only previously confirmed names on every refresh.
    for name in pairs(state.HitNames) do
        local ok, widget = pcall(findWidget, rootWidget, name)
        if ok and widget ~= nil then
            walkWidgetDescendants(widget, setmetatable({}, { __mode = "k" }), function(candidate)
                translateTextWidget(candidate, discoveryContext)
            end)
        end
    end
    if state.Pending or state.Complete then return end

    state.Pending = true
    local names = loadGeneratedWidgetProbeNames()
    local function runBatch()
        if component and component.isDestroyed then
            state.Pending = false
            return
        end
        local finish = math.min(#names, state.NextIndex + WIDGET_PROBE_BATCH_SIZE - 1)
        for index = state.NextIndex, finish do
            local name = names[index]
            local ok, widget = pcall(findWidget, rootWidget, name)
            if ok and widget ~= nil then
                state.HitNames[name] = true
                walkWidgetDescendants(widget, state.Visited, function(candidate)
                    translateTextWidget(candidate, discoveryContext)
                end)
            end
        end
        state.NextIndex = finish + 1
        if state.NextIndex > #names then
            state.Pending = false
            state.Complete = true
        elseif not scheduleWidgetProbe(component, runBatch) then
            state.Pending = false
        end
    end
    if not scheduleWidgetProbe(component, runBatch) then runBatch() end
end

runtimeFixes.VisibleWidgetNames = {
    "Text_Name", "Text_Title", "Text_Power", "Text_PowerName",
    "Text_CEName", "Text_CETitle", "Text_ScoreName", "Text_Rating",
    "RTB_Text", "RTB_Name", "RTB_Title", "Text_lua", "Text2_lua",
    "Text_Recommend", "Text_Extra", "Text_BeStrong", "Text_Reset",
    "Text_Equip", "Text_Tips", "Text_BtnName", "Text_Plan",
    "Text_Content", "TextUsing", "TB_Word",
}

local function translateViewTextWidgets(view, userWidget, discoveryContext, component)
    invalidateWidgetCache(userWidget)
    local visited = {}
    local repairedCount = 0
    local function translateWidgetTree(owner)
        walkWidgetDescendants(owner, visited, function(widget)
            repairedCount = repairedCount + translateTextWidget(widget, discoveryContext)
        end)
    end

    -- Panel views frequently expose nested UserWidgets rather than their text
    -- blocks. Seed the recursive walk from every generated view entry so those
    -- child WidgetTrees are repaired even when the panel has no userWidget.
    if type(view) == "table" then
        for _, widget in pairs(view) do
            translateWidgetTree(widget)
        end
        -- Framework views cache lazily resolved Blueprint widgets here. They
        -- are not necessarily direct values in the generated view table.
        if type(view._widgetCache) == "table" then
            for _, widget in pairs(view._widgetCache) do
                translateWidgetTree(widget)
            end
        end
    end

    if userWidget == nil then
        return repairedCount
    end

    -- Static Blueprint text is not always included in the generated Lua view.
    -- Check the names used by the rating reminder and, where available, walk
    -- the widget tree so its label is translated after every refresh.
    for _, name in ipairs(runtimeFixes.VisibleWidgetNames) do
        translateWidgetTree(getNamedWidget(userWidget, name))
    end

    -- Nested UserWidgets own separate WidgetTrees, so recurse into each one.
    -- This is required for the skill screen's embedded top tabs and footer
    -- buttons, whose text does not belong to the panel's root tree.
    translateWidgetTree(userWidget)
    queueGeneratedWidgetProbe(userWidget, component, discoveryContext)
    return repairedCount
end

local function translateTableStrings(value, seen, captureContext, fieldPath)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return value
    end
    seen[value] = true

    fieldPath = fieldPath or ""
    for key, child in pairs(value) do
        local childPath = fieldPath == "" and tostring(key) or (fieldPath .. "." .. tostring(key))
        if type(child) == "string" then
            local translated = translateVisibleText(child)
            value[key] = translated
            if captureContext ~= nil then
                runtimeMetrics.CaptureDataAssignment(
                    captureContext.component,
                    captureContext.module,
                    captureContext.class,
                    childPath,
                    child,
                    translated,
                    captureContext.record
                )
            end
        elseif type(child) == "table" then
            translateTableStrings(child, seen, captureContext, childPath)
        end
    end
    return value
end

local function applyVisibleTextOverrides(value, environment)
    local module = value
    if type(module) ~= "table" then
        module = getSymbol(value, environment, "TopData")
    end
    if type(module) ~= "table" then
        return value
    end

    translateTableStrings(module)
    return value
end

local function applyVisibleFieldOverrides(moduleName, allowedFields)
    return function(value, environment)
        local module = value
        if type(module) ~= "table" then
            module = getSymbol(value, environment, "TopData")
        end
        if type(module) ~= "table" then
            return value
        end

        local seen = {}
        local function visit(node, recordIdentity, fieldPath)
            if type(node) ~= "table" or seen[node] then return end
            seen[node] = true
            for field, child in pairs(node) do
                local childPath = fieldPath == "" and tostring(field)
                    or (fieldPath .. "." .. tostring(field))
                if allowedFields[field] and type(child) == "string" then
                    local translated = translateVisibleText(child)
                    node[field] = translated
                    runtimeMetrics.CaptureDataAssignment(
                        nil,
                        moduleName,
                        "StaticDataRow",
                        childPath,
                        child,
                        translated,
                        recordIdentity
                    )
                elseif type(child) == "table" then
                    visit(child, recordIdentity or field, childPath)
                end
            end
        end

        visit(module.data or module, nil, "")
        return value
    end
end

local function explicitLookup(index, tag)
    if tag then
        local values = splitOverrides[tag]
        return values and values[index] or nil
    end
    return aggregateOverrides[index]
end

local function getDirectTable(tag)
    local cacheKey = tag or "__aggregate"
    local cached = directTables[cacheKey]
    if cached ~= nil then
        return cached ~= MISSING_DIRECT_TABLE and cached or nil
    end

    local suffix = tag and ("_" .. tag) or ""
    for _, candidate in ipairs({
        { "cpdd_translation.Data.Excel.LanguageData.StringDB_CN_Data" .. suffix, true },
        { "Data.Excel.LanguageData.StringDB_EN_Data" .. suffix, false },
        { "Data.Excel.LanguageData.StringDB_CN_Data" .. suffix, false },
    }) do
        local moduleName, external = candidate[1], candidate[2]
        local ok, module
        if external and type(Loader.LoadExternal) == "function" then
            ok, module = pcall(Loader.LoadExternal, moduleName)
        else
            ok, module = pcall(require, moduleName)
        end
        if ok and type(module) == "table" then
            local data = module.data or module
            if type(data) == "table" then
                directTables[cacheKey] = data
                report("using direct localization table " .. moduleName)
                return data
            end
        end
    end

    directTables[cacheKey] = MISSING_DIRECT_TABLE
    return nil
end

local function directLookup(index, tag)
    local data = getDirectTable(tag)
    return data and data[index] or nil
end

local bit = require("bit")

hasCjk = function(value)
    return type(value) == "string" and value:find("[\228-\233][\128-\191][\128-\191]") ~= nil
end

local function sourceKey(value)
    local hash = bit.tobit(2166136261)
    for index = 1, #value do
        hash = bit.bxor(hash, value:byte(index))
        hash = bit.tobit(
            hash
            + bit.lshift(hash, 1)
            + bit.lshift(hash, 4)
            + bit.lshift(hash, 7)
            + bit.lshift(hash, 8)
            + bit.lshift(hash, 24)
        )
    end
    return tostring(#value) .. ":" .. bit.tohex(hash)
end

local SOURCE_SHARD_CACHE_LIMIT = 64
local sourceShardCache = {}
local sourceShardOrder = {}
local missingSourceShards = {}

local function touchSourceShard(prefix)
    for index = #sourceShardOrder, 1, -1 do
        if sourceShardOrder[index] == prefix then
            table.remove(sourceShardOrder, index)
            break
        end
    end
    sourceShardOrder[#sourceShardOrder + 1] = prefix
    while #sourceShardOrder > SOURCE_SHARD_CACHE_LIMIT do
        local evicted = table.remove(sourceShardOrder, 1)
        sourceShardCache[evicted] = nil
        package.loaded["mods.cpdd_runtime_fixes.LanguageSourceIndex_" .. evicted] = nil
    end
end

local function sourceIndexLookup(key)
    local hashPrefix = type(key) == "string" and key:match(":([0-9a-f][0-9a-f])") or nil
    local prefix = hashPrefix and string.format("%02x", math.floor(tonumber(hashPrefix, 16) / 4)) or nil
    if prefix == nil or missingSourceShards[prefix] then
        runtimeMetrics.SourceShardMisses = runtimeMetrics.SourceShardMisses + 1
        return nil
    end

    local shard = sourceShardCache[prefix]
    if shard ~= nil then
        runtimeMetrics.SourceShardHits = runtimeMetrics.SourceShardHits + 1
        touchSourceShard(prefix)
        return shard[key]
    end

    local moduleName = "mods.cpdd_runtime_fixes.LanguageSourceIndex_" .. prefix
    local started = nowMilliseconds()
    local ok, loaded = pcall(require, moduleName)
    if not ok or type(loaded) ~= "table" then
        missingSourceShards[prefix] = true
        runtimeMetrics.SourceShardMisses = runtimeMetrics.SourceShardMisses + 1
        report("language source shard unavailable " .. prefix .. ": " .. tostring(loaded))
        return nil
    end
    sourceShardCache[prefix] = loaded
    touchSourceShard(prefix)
    runtimeMetrics.SourceShardLoads = runtimeMetrics.SourceShardLoads + 1
    local elapsed = nowMilliseconds() - started
    report("loaded language source shard " .. prefix .. " in "
        .. string.format("%.2f", elapsed) .. " ms")
    return loaded[key]
end

local function sourceReference(reference)
    if type(reference) == "number" then
        return nil, reference
    end
    if type(reference) ~= "string" then
        return nil, nil
    end
    local tag, languageId = reference:match("^([A-Za-z0-9_]+):(%d+)$")
    return tag, tag and tonumber(languageId) or nil
end

local function referenceScore(reference, tableName, fieldPath)
    if type(reference) ~= "string" then
        return 0
    end
    local tag = reference:match("^([A-Za-z0-9_]+):")
    if not tag then
        return 0
    end
    local context = (tostring(tableName or "") .. "." .. tostring(fieldPath or "")):lower()
    tag = tag:lower()
    local score = context:find(tag, 1, true) and 100 or 0
    for _, family in ipairs({
        "skill", "buff", "item", "talk", "task", "guide",
        "achievement", "manor", "gossip", "loading",
    }) do
        if context:find(family, 1, true) and tag:sub(1, #family) == family then
            score = score + 50
        end
    end
    if (context:find("dialog", 1, true) or context:find("npc", 1, true))
        and tag:find("talk", 1, true)
    then
        score = score + 25
    end
    return score
end

local function lookupSourceTranslation(sourceReferenceValue, tableName, fieldPath)
    local references = type(sourceReferenceValue) == "table"
        and sourceReferenceValue
        or { sourceReferenceValue }
    local translated, bestScore, conflicting = nil, -1, false
    for _, reference in ipairs(references) do
        local tag, languageId = sourceReference(reference)
        if languageId then
            local candidate = directLookup(languageId, tag) or explicitLookup(languageId, tag)
            if type(candidate) == "string" then
                candidate = translateVisibleText(candidate)
                local score = referenceScore(reference, tableName, fieldPath)
                if score > bestScore then
                    translated, bestScore, conflicting = candidate, score, false
                elseif score == bestScore and translated ~= candidate then
                    conflicting = true
                end
            end
        end
    end
    return conflicting and nil or translated
end

local liveRepairCache = {}
local liveRepairCacheSize = 0
local LIVE_REPAIR_CACHE_LIMIT = 8192

local function returnLiveRepairResult(tableName, rowKey, fieldPath, original, rendered)
    if runtimeMetrics.CaptureDataAssignmentsEnabled and hasCjk(rendered) then
        runtimeMetrics.CaptureDataAssignment(
            nil,
            tostring(tableName or "LiveString"),
            "LiveString",
            tostring(fieldPath or "value"),
            original,
            rendered,
            rowKey
        )
    end
    return rendered
end

repairLiveString = function(tableName, rowKey, fieldPath, value)
    local enterWorldShortened = shortenEnterWorldLabel(value)
    if enterWorldShortened ~= value then
        return enterWorldShortened
    end
    local questPasswordRestored = restoreQuestChatPassword(value)
    if questPasswordRestored ~= value then
        return questPasswordRestored
    end
    local reviewedExact = visibleTextExactOverrides[value]
    if reviewedExact ~= nil then
        return reviewedExact
    end
    if not hasCjk(value) then
        return value
    end

    -- Exact generated translations are authoritative for a complete source
    -- value. Consult them before either cache: an earlier fragment repair may
    -- have cached a mixed result such as "你在做What?", which must never mask
    -- the reviewed whole-string translation on KSBC rows.
    local geminiExact = lookupGeminiText(value)
    if type(geminiExact) == "string" and geminiExact ~= ""
        and not hasCjk(geminiExact)
    then
        return preserveMovableAnswerMarkup(value, geminiExact)
    end

    local cacheKey = tostring(tableName or "") .. "\0" .. tostring(fieldPath or "") .. "\0" .. value
    local cached = liveRepairCache[cacheKey]
    if cached ~= nil then
        runtimeMetrics.LiveRepairCacheHits = runtimeMetrics.LiveRepairCacheHits + 1
        return returnLiveRepairResult(tableName, rowKey, fieldPath, value, cached)
    end
    runtimeMetrics.LiveRepairCacheMisses = runtimeMetrics.LiveRepairCacheMisses + 1

    -- Dialogue captions may prepend a live player/NPC name to an otherwise
    -- authored StringDB line. Resolve the authored tail independently while
    -- preserving user-created names verbatim.
    local speakerPrefix, spokenText = value:match("^([^:：]-[:：]%s*)(.+)$")
    if speakerPrefix ~= nil and hasCjk(spokenText) then
        local exactSpoken = visibleTextExactOverrides[spokenText]
        if type(exactSpoken) == "string" and not hasCjk(exactSpoken) then
            local combined = translateVisibleText(speakerPrefix) .. exactSpoken
            if liveRepairCacheSize >= LIVE_REPAIR_CACHE_LIMIT then
                liveRepairCache = {}
                liveRepairCacheSize = 0
            end
            liveRepairCache[cacheKey] = combined
            liveRepairCacheSize = liveRepairCacheSize + 1
            return combined
        end
        local spokenReference = sourceIndexLookup(sourceKey(spokenText))
        if spokenReference ~= nil then
            local spokenTranslation = lookupSourceTranslation(spokenReference, tableName, fieldPath)
            if type(spokenTranslation) == "string" and not hasCjk(spokenTranslation) then
                local combined = translateVisibleText(speakerPrefix) .. spokenTranslation
                if liveRepairCacheSize >= LIVE_REPAIR_CACHE_LIMIT then
                    liveRepairCache = {}
                    liveRepairCacheSize = 0
                end
                liveRepairCache[cacheKey] = combined
                liveRepairCacheSize = liveRepairCacheSize + 1
                return combined
            end
        end
    end

    local known = translateVisibleText(value)
    local partialKnown = nil
    if known ~= value and not hasCjk(known) then
        if liveRepairCacheSize >= LIVE_REPAIR_CACHE_LIMIT then
            liveRepairCache = {}
            liveRepairCacheSize = 0
        end
        liveRepairCache[cacheKey] = known
        liveRepairCacheSize = liveRepairCacheSize + 1
        return known
    elseif known ~= value then
        -- A token replacement is only a fallback while Chinese remains.  The
        -- complete authored source may still have an authoritative StringDB
        -- entry, so do not let a partial replacement bypass that lookup.
        partialKnown = known
    end

    local sourceReferenceValue = sourceIndexLookup(sourceKey(value))
    if sourceReferenceValue ~= nil then
        local translated = lookupSourceTranslation(sourceReferenceValue, tableName, fieldPath)
        if type(translated) == "string" and translated ~= value and not hasCjk(translated) then
            if liveRepairCacheSize >= LIVE_REPAIR_CACHE_LIMIT then
                liveRepairCache = {}
                liveRepairCacheSize = 0
            end
            liveRepairCache[cacheKey] = translated
            liveRepairCacheSize = liveRepairCacheSize + 1
            return translated
        end
    end
    -- A source-index miss is stable for this release and is safe to cache.
    -- A known source whose direct table is not ready must remain retryable.
    if sourceReferenceValue == nil then
        if liveRepairCacheSize >= LIVE_REPAIR_CACHE_LIMIT then
            liveRepairCache = {}
            liveRepairCacheSize = 0
        end
        liveRepairCache[cacheKey] = partialKnown or value
        liveRepairCacheSize = liveRepairCacheSize + 1
    end
    return returnLiveRepairResult(
        tableName,
        rowKey,
        fieldPath,
        value,
        partialKnown or value
    )
end

-- Server hotfixes can replace values inside the live StringDB tables after
-- the English overlays were merged. The table identity does not change, so a
-- normal overlay reapply treats it as already translated. Force the reviewed
-- English rows back into every loaded StringDB after each hotfix batch.
local function installPostHotfixTranslationRestore(value, environment)
    local utils = type(value) == "table" and value
        or getSymbol(value, environment, "HotfixUtils")
        or (Game and Game.HotfixUtils)
    if type(utils) ~= "table" or utils.__cpddTranslationRestore == VERSION then
        return value
    end

    local originalPostHotfix = utils.PostHotfix
    if type(originalPostHotfix) ~= "function" then
        return value
    end

    utils.PostHotfix = function(...)
        local results = { originalPostHotfix(...) }
        local ok, count = pcall(Loader.ReapplyOverlays, true)
        if ok then
            report(
                "restored translated overlays after server hotfix modules="
                .. tostring(count or 0)
            )
        else
            report("post-hotfix translation restore failed: " .. tostring(count))
        end
        return unpack(results)
    end

    utils.__cpddTranslationRestore = VERSION
    report("installed post-hotfix translation restore")
    return value
end

Loader.AfterLoad(
    "Framework.DoraSDK.HotfixUtils",
    installPostHotfixTranslationRestore,
    1000001,
    "cpdd.runtime-fix.post-hotfix-translation-restore"
)

local function repairWidgetBlueprintTextData(value, environment, source)
    local module = value
    if type(module) ~= "table" then
        module = getSymbol(value, environment, "TopData")
    end
    if type(module) ~= "table" then
        return value
    end

    local data = module.data or module
    if type(data) ~= "table" then
        return value
    end

    local repairedCount = 0
    for rowKey, row in pairs(data) do
        if type(row) == "table" and type(row.DisplayString) == "string" then
            local repaired = repairLiveString(
                "WidgetBlueprintTextData",
                rowKey,
                "DisplayString",
                row.DisplayString
            )
            if repaired ~= row.DisplayString then
                row.DisplayString = repaired
                repairedCount = repairedCount + 1
            end
        end
    end
    if repairedCount > 0 then
        report("repaired " .. repairedCount .. " cached Blueprint text entries from " .. tostring(source))
    end
    return value
end

local function repairLiveValue(tableName, rowKey, fieldPath, value, depth, seen, maxDepth)
    local valueType = type(value)
    if valueType == "string" then
        local repaired = repairLiveString(tableName, rowKey, fieldPath, value)
        runtimeMetrics.CaptureDataAssignment(
            nil,
            tostring(tableName),
            "TableDataRow",
            fieldPath ~= "" and fieldPath or "value",
            value,
            repaired,
            rowKey
        )
        return repaired
    end
    if depth >= (maxDepth or 3)
        or seen[value]
        or (valueType ~= "table" and valueType ~= "userdata")
    then
        return value
    end

    local manager = Game and Game.TableDataManager
    if valueType == "userdata" and manager and type(manager.isSpecialUEType) == "function" then
        local ok, special = pcall(manager.isSpecialUEType, manager, value)
        if ok and special then
            return value
        end
    end
    seen[value] = true

    local iterator = valueType == "userdata" and rawget(_G, "ksbcpairs") or pairs
    if type(iterator) ~= "function" then
        return value
    end
    local ok, nextFunction, state, firstKey = pcall(iterator, value)
    if not ok or type(nextFunction) ~= "function" then
        return value
    end

    local entries = {}
    for field, child in nextFunction, state, firstKey do
        entries[#entries + 1] = { field, child }
    end

    local output = value
    for _, entry in ipairs(entries) do
        local field, child = entry[1], entry[2]
        local path = fieldPath == "" and tostring(field) or (fieldPath .. "." .. tostring(field))
        local repaired = repairLiveValue(
            tableName,
            rowKey,
            path,
            child,
            depth + 1,
            seen,
            maxDepth
        )
        if repaired ~= child then
            if output == value then
                output = {}
                for _, originalEntry in ipairs(entries) do
                    output[originalEntry[1]] = originalEntry[2]
                end
                if valueType == "table" then
                    setmetatable(output, getmetatable(value))
                end
            end
            output[field] = repaired
        end
    end
    return output
end

local function repairPickObjectSayTexts(value, environment)
    local module = value
    if type(module) ~= "table" then
        module = getSymbol(value, environment, "TopData")
    end
    if type(module) ~= "table" then
        return value
    end

    local data = module.data or module
    if type(data) ~= "table" then
        return value
    end

    local visited = {}
    local sayActions = 0
    local repairedActions = 0

    local function visit(node, rowKey, fieldPath, depth)
        if type(node) ~= "table" or visited[node] or depth > 12 then
            return
        end
        visited[node] = true

        local isSay = node.FuncName == "Say" and type(node.FuncArgInfos) == "table"
        if isSay then
            sayActions = sayActions + 1
            local repaired = repairLiveValue(
                "PickObjectData",
                rowKey,
                fieldPath .. ".FuncArgInfos",
                node.FuncArgInfos,
                0,
                {},
                8
            )
            if repaired ~= node.FuncArgInfos then
                node.FuncArgInfos = repaired
                repairedActions = repairedActions + 1
            end
        end

        for field, child in pairs(node) do
            if type(child) == "table" and not (isSay and field == "FuncArgInfos") then
                visit(child, rowKey, fieldPath .. "." .. tostring(field), depth + 1)
            end
        end
    end

    for rowKey, row in pairs(data) do
        visit(row, rowKey, tostring(rowKey), 0)
    end

    if sayActions > 0 then
        report(
            "processed PickObjectData Say actions=" .. tostring(sayActions)
            .. " repaired=" .. tostring(repairedActions)
        )
    end
    return value
end

for _, moduleName in ipairs({
    "Data.Excel.WidgetBlueprintTextData",
    "Data.Excel.DialogueTalkData",
    "Data.Excel.DialogueAssetData",
    "Data.Excel.DialogueOptionText",
    "Data.Excel.LetterTextData",
    "Data.Excel.NpcInfoData",
}) do
    Loader.AfterLoad(
        moduleName,
        applyVisibleTextOverrides,
        1000000,
        "cpdd.runtime-fix.visible-text." .. moduleName:gsub("[^%w]", "-")
    )
end

local visibleFieldOverrideSpecs = {
    { "Data.Excel.ActivityNameData", { Name = true } },
    { "Data.Excel.BattleBotTemplateData", { Name = true } },
    { "Data.Excel.BoxManLevelData", { LevelDesc = true, LevelName = true } },
    -- Gossip and world-bubble tables are resolved before their widgets exist.
    -- Traverse the authored tables once when loaded so every line is repaired
    -- and every genuine miss is captured without waiting for it to appear.
    { "Data.Excel.BubbleData", { BubbleText = true } },
    { "Data.Excel.BuffDataNew", { UIName = true } },
    { "Data.Excel.ClientNpcData", { Name = true } },
    { "Data.Excel.DungeonRewardData", { SocialRewardDesc = true } },
    { "Data.Excel.FashionStationOfficialAccountData", { Name = true } },
    { "Data.Excel.FashionStationOfficialPostsData", { pDesc = true, pName = true } },
    { "Data.Excel.GossipData", { Text = true } },
    { "Data.Excel.MonsterData", { Name = true } },
    { "Data.Excel.NoCameraDialogueGossipData", { Text = true } },
    { "Data.Excel.SpecialNickNameData", { Nickname = true } },
    { "Data.Excel.TextControlSentenceData", { TextInfo = true, word = true } },
}

for _, spec in ipairs(visibleFieldOverrideSpecs) do
    local moduleName = spec[1]
    Loader.AfterLoad(
        moduleName,
        applyVisibleFieldOverrides(moduleName, spec[2]),
        1000000,
        "cpdd.runtime-fix.visible-fields." .. moduleName:gsub("[^%w]", "-")
    )
end

Loader.AfterLoad(
    "Data.Excel.WidgetBlueprintTextData",
    function(value, environment)
        return repairWidgetBlueprintTextData(value, environment, "loader")
    end,
    1000001,
    "cpdd.runtime-fix.widget-blueprint-source"
)

Loader.AfterLoad(
    "Data.Excel.PickObjectData",
    repairPickObjectSayTexts,
    1000000,
    "cpdd.runtime-fix.pick-object-say-texts"
)

local function fillLocalizedField(row, field, key, tag, force)
    if not force and row[field] ~= nil and row[field] ~= "" then
        return
    end
    local value = directLookup(key, tag) or explicitLookup(key, tag)
    if value ~= nil then
        row[field] = translateVisibleText(value)
    end
end

local function normalizeSkillId(skillId)
    if type(skillId) == "number" then
        return skillId
    end
    local ok, numericId = pcall(tonumber, skillId)
    if ok and type(numericId) == "number" then
        return numericId
    end
    return nil
end

local function getMarionetteSkillLocalizationById(skillId)
    skillId = normalizeSkillId(skillId)
    if skillId == nil then
        return nil, false, nil
    end

    local keys = marionetteSkillLocalization[skillId]
    if keys then
        return keys, true, skillId
    end

    -- Runtime/upgraded variants reuse the base row's name localization key,
    -- but intentionally leave their own description fields empty. Most
    -- families use the final digit as a variant index. The Alien Hound family
    -- starts at 04 instead of 00.
    local baseSkillId = skillId - skillId % 10
    keys = marionetteSkillLocalization[baseSkillId]
    if not keys and skillId >= 87303004 and skillId <= 87303009 then
        baseSkillId = 87303004
        keys = marionetteSkillLocalization[87303004]
    end
    return keys, false, keys and baseSkillId or nil
end

local function getMarionetteSkillLocalization(skillId, row)
    local keys, isBaseRow, mappedSkillId = getMarionetteSkillLocalizationById(skillId)
    if keys then
        return keys, isBaseRow, mappedSkillId
    end

    if type(row) ~= "table" then
        return nil, false, nil
    end

    for _, candidate in ipairs({ row.ID, row.InitialSkill, row.InitialSkillID, row.RoleSkillID }) do
        keys, isBaseRow, mappedSkillId = getMarionetteSkillLocalizationById(candidate)
        if keys then
            return keys, isBaseRow, mappedSkillId
        end
    end

    for _, field in ipairs({ "SkillDisplayIcon", "SkillIcon", "IconTexture" }) do
        local icon = row[field]
        if type(icon) == "string" then
            local iconNumber = tonumber(icon:match("SecretPartner_Skill_(%d+)"))
            local iconSkillId = iconNumber and marionetteSkillIdByIconNumber[iconNumber]
            if iconSkillId then
                return marionetteSkillLocalization[iconSkillId], false, iconSkillId
            end
        end
    end

    return nil, false, nil
end

local function repairMarionetteSkillRow(row, skillId)
    local keys, isBaseRow, mappedSkillId = getMarionetteSkillLocalization(skillId, row)
    if type(row) ~= "table" or not keys then
        return row
    end

    -- The official row can already contain the shared Chinese placeholder
    -- when it was cached before the StringDB overlays were applied. Always
    -- replace mapped Marionette fields from their exact translated keys.
    fillLocalizedField(row, "Name", keys[1], "skill3", true)
    if marionetteEnglishNames[mappedSkillId]
        and (row.Name == nil or row.Name == "" or hasCjk(row.Name)) then
        row.Name = marionetteEnglishNames[mappedSkillId]
    end
    if isBaseRow then
        fillLocalizedField(row, "BriefDescription", keys[2], "skill3", true)
        fillLocalizedField(row, "SkillDisc", keys[3], "skill3", true)
        fillLocalizedField(row, "Tag", keys[4], nil, true)
    end
    return row
end

local function isMarionetteSkillRow(row, skillId)
    local numericId = normalizeSkillId(skillId)
    if not numericId and type(row) == "table" then
        numericId = normalizeSkillId(row.ID) or normalizeSkillId(row.InitialSkill)
    end
    if numericId and numericId >= 87303000 and numericId < 87304000 then
        return true
    end
    if type(row) == "table" then
        for _, field in ipairs({ "SkillDisplayIcon", "SkillIcon", "IconTexture" }) do
            local icon = row[field]
            if type(icon) == "string" and icon:find("SecretPartner_Skill_", 1, true) then
                return true
            end
        end
    end
    return false
end

Loader.AfterLoad("Framework.Utils.LuaCommon.Managers.TableDataManager", function(value, environment)
    local manager = getSymbol(value, environment, "TableDataManager")
    if type(manager) ~= "table" or manager.__cpddRuntimeFixV1 then
        return value
    end

    manager.__cpddRuntimeFixV1 = true
    local originalGetLangStr = assert(manager.GetLangStr)
    local originalGetLangStrSplit = assert(manager.GetLangStrSplit)
    local originalGetRow = manager.GetRow

    function manager:GetLangStr(index)
        local ok, result = pcall(originalGetLangStr, self, index)
        if ok and result ~= nil then
            if type(result) == "string" then
                return repairLiveString(
                    "LanguageData.StringDB_CN_Data",
                    index,
                    "Value",
                    result
                )
            end
            return result
        end

        -- Numeric IDs are not stable across the base PAK and the active KMF
        -- localization cache. Only use an ID overlay when the live provider
        -- returned no source value that could be translated exactly.
        local replacement = directLookup(index, nil) or explicitLookup(index, nil)
        if replacement ~= nil then
            return translateVisibleText(replacement)
        end

        if type(index) == "string" and hasCjk(index) then
            local translated = repairLiveString(
                "LanguageData.StringDB_CN_Data",
                index,
                "RawText",
                index
            )
            if translated ~= index then
                return translated
            end
        end

                return nil
    end

    function manager:GetLangStrSplit(index, tag)
        local ok, result = pcall(originalGetLangStrSplit, self, index, tag)
        if ok and result ~= nil then
            if type(result) == "string" then
                return repairLiveString(
                    "LanguageData.StringDB_CN_Data_" .. tostring(tag or ""),
                    index,
                    "Value",
                    result
                )
            end
            return result
        end

        local replacement = directLookup(index, tag) or explicitLookup(index, tag)
        if replacement ~= nil then
            return translateVisibleText(replacement)
        end

        if type(index) == "string" and hasCjk(index) then
            local translated = repairLiveString(
                "LanguageData.StringDB_CN_Data_" .. tostring(tag or ""),
                index,
                "RawText",
                index
            )
            if translated ~= index then
                return translated
            end
        end

                return nil
    end

    if type(originalGetRow) == "function" then
        function manager:GetRow(tableName, rowKey, priority)
            local languagePrefix = "LanguageData.StringDB_CN_Data"
            if type(tableName) == "string" and tableName:sub(1, #languagePrefix) == languagePrefix then
                local suffix = tableName:sub(#languagePrefix + 1)
                local tag = suffix:sub(1, 1) == "_" and suffix:sub(2) or nil
                if tag == "" then
                    tag = nil
                end
                local ok, result = pcall(
                    originalGetRow,
                    self,
                    tableName,
                    rowKey,
                    priority
                )
                if ok and result ~= nil then
                    if type(result) == "string" then
                        return repairLiveString(tableName, rowKey, "Value", result)
                    end
                    return result
                end
                local translated = directLookup(rowKey, tag) or explicitLookup(rowKey, tag)
                if translated ~= nil then
                    return translateVisibleText(translated)
                end
                return nil
            end

            return originalGetRow(self, tableName, rowKey, priority)
        end
    end

    report("installed translated localization lookup")
    return value
end, 1000000, "cpdd.runtime-fix.localization")

-- Only these generated helpers have confirmed runtime-only localization gaps.
-- Iterating this tiny list avoids scanning and wrapping every TableData helper.
local generatedRowRepairAllowlist = {
    "GetGossipGroupDataRow",
    "GetGossipDataRow",
    "GetBubbleDataRow",
    "GetNoCameraDialogueGossipDataRow",
    "GetSkillDataNewRow",
    "GetBuffDataNewRow",
    "GetFellowDataRow",
    "GetStringConstDataRow",
    "GetTextControlSentenceDataRow",
    "GetItemNewDataRow",
    "GetEquipmentUniqueDataRow",
    "GetEquipmentMythDataRow",
    "GetEquipmentSuitDataRow",
    "GetEquipmentSpiritualityConvergenceDataRow",
    "GetEquipWordAtkFixedGroupDataRow",
    "GetEquipWordAtkFixedWordDataRow",
    "GetSealedInfoAttrDataRow",
    "GetSealedInfoDataRow",
    "GetMythicGlobalDataRow",
    "GetXtraMatNameRuleDataRow",
    "GetDungeonRewardDataRow",
    "GetNpcInfoDataRow",
    "GetNickNameLibDataRow",
    "GetCommonInteractorActionDataRow",
    "GetLetterTextDataRow",
    "GetFourFactionBattleConstDataRow",
    "GetFortuityDataRow",
    "GetTaskMiniTypeDataRow",
}
local generatedRowRepairCache = setmetatable({}, { __mode = "k" })

local function wrapGeneratedRowHelper(helperName, original)
    return function(...)
        local rowKey = select(1, ...)
        local row = original(...)
        if not runtimeRowRepairEnabled() then
            return row
        end

        local rowType = type(row)
        if rowType == "table" or rowType == "userdata" then
            local cached = generatedRowRepairCache[row]
            if cached and cached[helperName] ~= nil then
                return cached[helperName]
            end
        end

        if helperName == "GetSkillDataNewRow" then
            row = repairMarionetteSkillRow(row, rowKey)
        elseif helperName == "GetBuffDataNewRow" and rowKey == 82071030 and type(row) == "table" then
            fillLocalizedField(row, "BuffName", 211107038233344, "buffdata")
            fillLocalizedField(row, "BuffName1", 211107038233344, "buffappear")
            fillLocalizedField(row, "BuffDisc", 211107843539712, nil)
        end
        local repaired = repairLiveValue(helperName, rowKey, "", row, 0, {})
        if rowType == "table" or rowType == "userdata" then
            local cached = generatedRowRepairCache[row]
            if cached == nil then
                cached = setmetatable({}, { __mode = "v" })
                generatedRowRepairCache[row] = cached
            end
            cached[helperName] = repaired
        end
        return repaired
    end
end

local function installTableDataRowRepair(tableData, source)
    if type(tableData) ~= "table" then
        return false
    end

    local wrappers = tableData.__cpddRuntimeFixGeneratedRowWrappers
    if type(wrappers) ~= "table" then
        wrappers = {}
    end

    local wrapped = 0
    for _, helperName in ipairs(generatedRowRepairAllowlist) do
        local member = tableData[helperName]
        if type(member) == "function" and wrappers[helperName] ~= member then
            local original = member
            local wrapper = wrapGeneratedRowHelper(helperName, original)
            tableData[helperName] = wrapper
            wrappers[helperName] = wrapper
            wrapped = wrapped + 1
        end
    end

    tableData.__cpddRuntimeFixGeneratedRowWrappers = wrappers
    tableData.__cpddRuntimeFixRows = VERSION
    if wrapped > 0 then
        report(
            "installed generated TableData row repair on " .. tostring(source)
            .. " helpers=" .. tostring(wrapped)
        )
    end
    return wrapped > 0
end

local tableDataProbesLogged = {}
local function ensureGameTableDataRowRepair(source)
    local tableData = Game and Game.TableData
    local installed = installTableDataRowRepair(tableData, source)
    if not tableDataProbesLogged[source] then
        tableDataProbesLogged[source] = true
        report(
            "probed Game.TableData from " .. tostring(source)
            .. " type=" .. type(tableData)
            .. " installed=" .. tostring(installed)
            .. " target=" .. tostring(tableData)
        )
    end
    return installed
end

local function tableDataFrom(value, environment)
    if type(value) == "table" and type(value.GetSkillDataNewRow) == "function" then
        return value
    end
    if type(value) == "table" and type(value.TableData) == "table" then
        return value.TableData
    end
    if type(environment) == "table" and type(environment.TableData) == "table" then
        return environment.TableData
    end
    return Game and Game.TableData
end

Loader.AfterLoad("Data.Excel.TableData", function(value, environment)
    local tableData = tableDataFrom(value, environment)
    installTableDataRowRepair(tableData, "Data.Excel.TableData")
    ensureGameTableDataRowRepair("Data.Excel.TableData callback")
    return value
end, 1000000, "cpdd.runtime-fix.table-rows")

-- KsbcMgr replaces Game.TableDataManager.GetRow after the ordinary manager
-- localization hook is installed. Some Sealed Artifact rows therefore reach
-- the UI with already-resolved Chinese strings and never pass through
-- GetLangStr or the generated Data.Excel.TableData helpers. Repair only the
-- confirmed player-facing equipment tables at that authoritative boundary.
local managerRowRepairTables = {
    EquipmentUniqueData = true,
    EquipmentMythData = true,
    EquipmentSuitData = true,
    EquipmentSpiritualityConvergenceData = true,
    EquipWordAtkFixedGroupData = true,
    EquipWordAtkFixedWordData = true,
    SealedInfoAttrData = true,
    SealedInfoData = true,
}

-- KsbcMgr replaces the normal table getters with direct archive indexing. A
-- server hotfix can legitimately reference a Lua table omitted from that
-- archive; the shipped getter then indexes nil and aborts the entire hotfix.
-- Capture the ordinary getters before KsbcMgr.Init and use them only when the
-- requested KSBC entry is absent.
runtimeFixes.KsbcFallbackMethods = setmetatable({}, { __mode = "k" })
runtimeFixes.KsbcFallbackReports = {}

function runtimeFixes.installKsbcMissingTableFallback(manager, source)
    local fallbacks = type(manager) == "table"
        and runtimeFixes.KsbcFallbackMethods[manager] or nil
    local ksbcManager = Game and Game.KsbcMgr
    if type(fallbacks) ~= "table"
        or ksbcManager == nil
        or ksbcManager.entry == nil
        or type(manager.GetRow) ~= "function"
        or type(manager.GetData) ~= "function"
        or type(manager.GetAttr) ~= "function"
    then
        return false
    end

    local installed = manager.__cpddKsbcMissingTableFallback
    if type(installed) == "table"
        and installed.Version == VERSION
        and installed.GetData == manager.GetData
        and installed.GetAttr == manager.GetAttr
    then
        return false
    end

    local ksbcGetRow = manager.GetRow
    local ksbcGetData = manager.GetData
    local ksbcGetAttr = manager.GetAttr
    local function isMissing(tableName)
        if type(tableName) ~= "string" then return false end
        local current = Game and Game.KsbcMgr
        local entry = current and current.entry
        if entry == nil then return true end
        local ok, value = pcall(function() return entry[tableName] end)
        return not ok or value == nil
    end
    local function noteFallback(methodName, tableName)
        runtimeMetrics.KsbcFallbacks = runtimeMetrics.KsbcFallbacks + 1
        local key = tostring(methodName) .. ":" .. tostring(tableName)
        if not runtimeFixes.KsbcFallbackReports[key] then
            runtimeFixes.KsbcFallbackReports[key] = true
            report("KSBC " .. tostring(methodName) .. " used normal table fallback for "
                .. tostring(tableName))
        end
    end

    local rowWrapper = function(self, tableName, rowKey, priority)
        if isMissing(tableName) then
            noteFallback("GetRow", tableName)
            return fallbacks.GetRow(self, tableName, rowKey, priority)
        end
        return ksbcGetRow(self, tableName, rowKey, priority)
    end
    local dataWrapper = function(self, tableName, priority)
        if isMissing(tableName) then
            noteFallback("GetData", tableName)
            return fallbacks.GetData(self, tableName, priority)
        end
        return ksbcGetData(self, tableName, priority)
    end
    local attrWrapper = function(self, tableName, attrName)
        if isMissing(tableName) then
            noteFallback("GetAttr", tableName)
            return fallbacks.GetAttr(self, tableName, attrName)
        end
        return ksbcGetAttr(self, tableName, attrName)
    end

    manager.GetRow = rowWrapper
    manager.GetData = dataWrapper
    manager.GetAttr = attrWrapper
    manager.__cpddKsbcMissingTableFallback = {
        Version = VERSION,
        GetRow = rowWrapper,
        GetData = dataWrapper,
        GetAttr = attrWrapper,
    }
    report("installed safe KSBC missing-table fallback from " .. tostring(source))
    return true
end

local function normalizedManagerTableName(tableName)
    if type(tableName) ~= "string" then
        return nil
    end
    return tableName:gsub("^Data%.Excel%.", "")
end

local function installRuntimeManagerRowRepair(manager, source)
    if type(manager) ~= "table" or type(manager.GetRow) ~= "function" then
        return false
    end

    local current = manager.GetRow
    local installed = manager.__cpddRuntimeManagerRowRepair
    if type(installed) == "table"
        and installed.Version == VERSION
        and installed.Wrapper == current
    then
        return false
    end

    local originalGetRow = current
    local wrapper = function(self, tableName, rowKey, priority)
        local row = originalGetRow(self, tableName, rowKey, priority)
        local normalized = normalizedManagerTableName(tableName)
        if not runtimeRowRepairEnabled()
            or normalized == nil
            or not managerRowRepairTables[normalized]
        then
            return row
        end
        return repairLiveValue(normalized, rowKey, "", row, 0, {}, 4)
    end

    manager.GetRow = wrapper
    manager.__cpddRuntimeManagerRowRepair = {
        Version = VERSION,
        Wrapper = wrapper,
        Original = originalGetRow,
    }
    report("installed live KSBC equipment-row repair from " .. tostring(source))
    return true
end

local function installKsbcManagerRowRepair(value, environment)
    local managerClass = getSymbol(value, environment, "KsbcMgr")
    if type(managerClass) ~= "table"
        or managerClass.__cpddRuntimeManagerRowRepair == VERSION
    then
        return value
    end

    local originalInit = managerClass.Init
    if type(originalInit) == "function" then
        managerClass.Init = function(self, ...)
            local manager = Game and Game.TableDataManager
            if type(manager) == "table"
                and runtimeFixes.KsbcFallbackMethods[manager] == nil
            then
                runtimeFixes.KsbcFallbackMethods[manager] = {
                    GetRow = manager.GetRow,
                    GetData = manager.GetData,
                    GetAttr = manager.GetAttr,
                }
            end
            local results = { originalInit(self, ...) }
            runtimeFixes.installKsbcMissingTableFallback(manager, "KsbcMgr.Init")
            installRuntimeManagerRowRepair(
                manager,
                "KsbcMgr.Init"
            )
            return unpack(results)
        end
    end

    managerClass.__cpddRuntimeManagerRowRepair = VERSION
    installRuntimeManagerRowRepair(
        Game and Game.TableDataManager,
        "KsbcMgr loader callback"
    )
    return value
end


Loader.AfterLoad(
    "Framework.Ksbc.KsbcMgr",
    installKsbcManagerRowRepair,
    1000001,
    "cpdd.runtime-fix.ksbc-equipment-rows"
)

Loader.On("after_main", function()
    installRuntimeManagerRowRepair(
        Game and Game.TableDataManager,
        "after_main"
    )
end, 1000001, "cpdd.runtime-fix.ksbc-equipment-rows-main")

local SCENE_TEXT_PRIMARY_ROW_MAX = 12
local SCENE_TEXT_TITLE_MAX = 80
local SCENE_TEXT_HEIGHT_MULTIPLIER = 2
local SCENE_TEXT_INNER_HEIGHT = 640
local SCENE_TEXT_MAIN_LINE_CHAR_BUDGET = 15
local SCENE_TEXT_MAX_ENGLISH_FONT_SIZE = 71
local SCENE_TEXT_MIN_FONT_SIZE = 48
local sceneTextSurfaceReports = 0
local sceneTextSurfaceFailures = 0
local sceneTextSurfaceApplied = setmetatable({}, { __mode = "k" })
local sceneTextInnerReports = 0
local sceneTextInnerApplied = setmetatable({}, { __mode = "k" })
local sceneTextWidgetComponentClass
local sceneTextImportedObjectActorManager

local function needsTallEnglishSceneText(value)
    if type(value) ~= "string" then
        return false
    end
    local plain = value:gsub("<.->", "")
    return plain:find("[A-Za-z]") ~= nil
        and (#plain > SCENE_TEXT_PRIMARY_ROW_MAX or plain:find("[\r\n]") ~= nil)
end

local function isPlainAsciiSceneTitle(value)
    if type(value) ~= "string" or value == "" or #value > SCENE_TEXT_TITLE_MAX then
        return false
    end
    if value:find("[\r\n]") or value:find("<", 1, true) or value:find(">", 1, true) then
        return false
    end
    for index = 1, #value do
        local byte = value:byte(index)
        if byte < 32 or byte > 126 then
            return false
        end
    end
    return true
end

local function reflowEnglishSceneTitle(displayText, leonSubTitle)
    if not isPlainAsciiSceneTitle(displayText)
        or (leonSubTitle ~= nil and leonSubTitle ~= "")
        or #displayText <= SCENE_TEXT_PRIMARY_ROW_MAX then
        return displayText, leonSubTitle
    end

    local words = {}
    for word in displayText:gmatch("%S+") do
        words[#words + 1] = word
    end
    if #words < 2 then
        return displayText, leonSubTitle
    end

    local bestIndex
    local bestScore
    for index = 1, #words - 1 do
        local primary = table.concat(words, " ", 1, index)
        local continuation = table.concat(words, " ", index + 1)
        local overflow = math.max(0, #primary - SCENE_TEXT_PRIMARY_ROW_MAX)
        local score = overflow * 100 + math.abs(#primary - #continuation)
        if bestScore == nil or score < bestScore then
            bestIndex = index
            bestScore = score
        end
    end

    return table.concat(words, " ", 1, bestIndex),
        table.concat(words, " ", bestIndex + 1)
end

local function removeRedundantAuthoredSceneSubtitle(displayText, leonSubTitle)
    if leonSubTitle ~= nil or type(displayText) ~= "string" then
        return displayText, leonSubTitle, false
    end
    local primary, authoredSubtitle = displayText:match(
        "^%s*(.-)%s*[\r\n]+%s*<LeonSubTitle[^>]*>(.-)</>%s*$"
    )
    if not isPlainAsciiSceneTitle(primary) then
        return displayText, leonSubTitle, false
    end
    authoredSubtitle = authoredSubtitle and authoredSubtitle:gsub("<.->", "") or ""
    if not isPlainAsciiSceneTitle(authoredSubtitle) then
        return displayText, leonSubTitle, false
    end
    return primary, nil, true
end

local function sceneTextImport(name)
    if type(import) ~= "function" then
        return nil
    end
    local ok, imported = pcall(import, name)
    if ok then
        return imported
    end
    return nil
end

local function sceneTextObjectByID(manager, objectID)
    if manager == nil then
        return nil
    end
    local getter = manager.GetObjectByID
    if type(getter) ~= "function" then
        return nil
    end
    local ok, object = pcall(getter, objectID)
    if ok and object ~= nil then
        return object
    end
    ok, object = pcall(getter, manager, objectID)
    if ok then
        return object
    end
    return nil
end

local function sceneTextObjectActorManager()
    if type(Game) == "table" and Game.ObjectActorManager ~= nil then
        return Game.ObjectActorManager
    end
    sceneTextImportedObjectActorManager = sceneTextImportedObjectActorManager
        or sceneTextImport("KGObjectActorManager")
    return sceneTextImportedObjectActorManager
end

local function sceneTextVector2D(x, y)
    if type(FVector2D) == "function" then
        local ok, value = pcall(FVector2D, x, y)
        if ok then
            return value
        end
    end
    return { X = x, Y = y }
end

local function liveSceneTextWidgetComponent(self)
    local cppEntity = self and self.CppEntity
    if cppEntity == nil or type(cppEntity.KAPI_Actor_GetComponentByClass) ~= "function" then
        return nil
    end
    sceneTextWidgetComponentClass = sceneTextWidgetComponentClass
        or sceneTextImport("WidgetComponent")
    local objectActorManager = sceneTextObjectActorManager()
    if sceneTextWidgetComponentClass == nil or objectActorManager == nil then
        return nil
    end
    local idOk, componentID = pcall(
        cppEntity.KAPI_Actor_GetComponentByClass,
        cppEntity,
        sceneTextWidgetComponentClass
    )
    if not idOk or componentID == nil then
        return nil
    end
    return sceneTextObjectByID(objectActorManager, componentID)
end

local function fitEnglishSceneTextFont(self)
    local displayText = self and self.displayText
    local cppEntity = self and self.CppEntity
    if type(displayText) ~= "string" or cppEntity == nil then
        return false
    end
    local primary = displayText:match("^([^\r\n]+)") or displayText
    primary = primary:gsub("<.->", "")
    if not isPlainAsciiSceneTitle(primary) then
        return false
    end
    local fontInfo = self.SceneConf and self.SceneConf.FontInfo
    local baseSize = fontInfo and tonumber(fontInfo.Size)
    if not baseSize or baseSize <= 0 then
        return false
    end
    local targetSize = baseSize
    if #primary > SCENE_TEXT_PRIMARY_ROW_MAX then
        targetSize = math.min(targetSize, SCENE_TEXT_MAX_ENGLISH_FONT_SIZE)
        if #primary > SCENE_TEXT_MAIN_LINE_CHAR_BUDGET then
            targetSize = math.min(
                targetSize,
                math.max(
                    SCENE_TEXT_MIN_FONT_SIZE,
                    math.floor(baseSize * SCENE_TEXT_MAIN_LINE_CHAR_BUDGET / #primary + 0.5)
                )
            )
        end
    end
    local changed = false
    if type(cppEntity.KAPI_Actor_UpdateFontSize) == "function" then
        changed = pcall(cppEntity.KAPI_Actor_UpdateFontSize, cppEntity, targetSize) or changed
    end
    if type(cppEntity.KAPI_Actor_UpdateFontLetterSpacing) == "function" then
        changed = pcall(cppEntity.KAPI_Actor_UpdateFontLetterSpacing, cppEntity, 0) or changed
    end
    return changed
end

local function repairEnglishSceneTextInnerLayout(self, phase)
    if type(self) ~= "table"
        or sceneTextInnerApplied[self]
        or not needsTallEnglishSceneText(self.displayText) then
        return false
    end
    local component = liveSceneTextWidgetComponent(self)
    if component == nil or type(component.GetUserWidgetObject) ~= "function" then
        return false
    end
    local rootOk, root = pcall(component.GetUserWidgetObject, component)
    if not rootOk or root == nil then
        return false
    end
    local sizeBox = getNamedWidget(root, "SizeBox_0")
    local textDetail = getNamedWidget(root, "Text_Detail")
    local changed = false
    if sizeBox ~= nil then
        if type(sizeBox.SetHeightOverride) == "function" then
            changed = pcall(sizeBox.SetHeightOverride, sizeBox, SCENE_TEXT_INNER_HEIGHT) or changed
        end
        if type(sizeBox.SetMinDesiredHeight) == "function" then
            changed = pcall(sizeBox.SetMinDesiredHeight, sizeBox, SCENE_TEXT_INNER_HEIGHT) or changed
        end
        pcall(function()
            if sizeBox.InvalidateLayoutAndVolatility ~= nil then
                sizeBox:InvalidateLayoutAndVolatility()
            end
        end)
    end
    if textDetail ~= nil then
        pcall(function()
            local slot = textDetail.Slot
            if slot ~= nil and slot.SetAutoSize ~= nil then
                slot:SetAutoSize(true)
                changed = true
            end
        end)
        pcall(function()
            if textDetail.InvalidateLayoutAndVolatility ~= nil then
                textDetail:InvalidateLayoutAndVolatility()
            end
        end)
    end
    if not changed then
        return false
    end
    sceneTextInnerApplied[self] = true
    if sceneTextInnerReports < 5 then
        sceneTextInnerReports = sceneTextInnerReports + 1
        report(string.format(
            "repaired inner scene text layout phase=%s sizebox=%s text=%s height=%s",
            tostring(phase),
            tostring(sizeBox ~= nil),
            tostring(textDetail ~= nil),
            tostring(SCENE_TEXT_INNER_HEIGHT)
        ))
    end
    return true
end

local function enlargeEnglishSceneTextSurface(self, phase)
    if type(self) ~= "table"
        or sceneTextSurfaceApplied[self]
        or not needsTallEnglishSceneText(self.displayText) then
        return false
    end
    local component = liveSceneTextWidgetComponent(self)
    if component == nil
        or type(component.GetDrawSize) ~= "function"
        or type(component.SetDrawSize) ~= "function" then
        if sceneTextSurfaceFailures < 3 then
            sceneTextSurfaceFailures = sceneTextSurfaceFailures + 1
            report("scene text surface unavailable phase=" .. tostring(phase))
        end
        return false
    end
    local sizeOk, drawSize = pcall(component.GetDrawSize, component)
    local width = sizeOk and drawSize and tonumber(drawSize.X)
    local height = sizeOk and drawSize and tonumber(drawSize.Y)
    if not width or not height or width <= 0 or height <= 0 then
        return false
    end
    local newHeight = math.max(height + 64, math.floor(height * SCENE_TEXT_HEIGHT_MULTIPLIER + 0.5))
    local setOk = pcall(
        component.SetDrawSize,
        component,
        sceneTextVector2D(width, newHeight)
    )
    if not setOk then
        return false
    end
    sceneTextSurfaceApplied[self] = true
    if sceneTextSurfaceReports < 5 then
        sceneTextSurfaceReports = sceneTextSurfaceReports + 1
        report(string.format(
            "enlarged live scene text surface phase=%s size=%sx%s->%sx%s text=%q",
            tostring(phase),
            tostring(width),
            tostring(height),
            tostring(width),
            tostring(newHeight),
            tostring(self.displayText):sub(1, 160)
        ))
    end
    return true
end

Loader.AfterLoad(
    "Gameplay.NetEntities.SceneActor.Components.SceneTextBoardComponent",
    function(value, environment)
        local source = "Gameplay.NetEntities.SceneActor.Components.SceneTextBoardComponent"
        local class = getSymbol(value, environment, "SceneTextBoardComponent")
        if type(class) ~= "table" or class.__cpddSceneTextRepair == VERSION then
            return value
        end
        local originalSetDisplayText = class.SetDisplayText
        if type(originalSetDisplayText) ~= "function" then
            return value
        end
        class.SetDisplayText = function(self, displayText, leonSubTitle)
            if runtimeUIRepairEnabled() then
                displayText = repairLiveString(source, "SetDisplayText", "DisplayText", displayText)
                leonSubTitle = repairLiveString(source, "SetDisplayText", "LeonSubTitle", leonSubTitle)
                local removedAuthoredSubtitle
                displayText, leonSubTitle, removedAuthoredSubtitle = removeRedundantAuthoredSceneSubtitle(
                    displayText,
                    leonSubTitle
                )
                if not removedAuthoredSubtitle then
                    displayText, leonSubTitle = reflowEnglishSceneTitle(displayText, leonSubTitle)
                end
            end
            return originalSetDisplayText(self, displayText, leonSubTitle)
        end
        local originalRefreshContent = class.RefreshContent
        if type(originalRefreshContent) == "function" then
            class.RefreshContent = function(self, ...)
                if runtimeUIRepairEnabled() then
                    enlargeEnglishSceneTextSurface(self, "RefreshContent")
                end
                local result = originalRefreshContent(self, ...)
                if runtimeUIRepairEnabled() then
                    fitEnglishSceneTextFont(self)
                    repairEnglishSceneTextInnerLayout(self, "RefreshContent")
                end
                return result
            end
        end
        local originalInnerTextBlockReady = class.InnerTextBlockReady
        if type(originalInnerTextBlockReady) == "function" then
            class.InnerTextBlockReady = function(self, ...)
                local result = originalInnerTextBlockReady(self, ...)
                if runtimeUIRepairEnabled() then
                    fitEnglishSceneTextFont(self)
                    repairEnglishSceneTextInnerLayout(self, "InnerTextBlockReady")
                    enlargeEnglishSceneTextSurface(self, "InnerTextBlockReady")
                end
                return result
            end
        end
        class.__cpddSceneTextRepair = VERSION
        report("installed scene text translation and complete inner/outer layout repair")
        return value
    end,
    1000000,
    "cpdd.runtime-fix.scene-text"
)

for _, moduleName in ipairs({
    "Gameplay.LogicSystem.SkillCustomizer.Main.Skill_Fight_Item",
    "Gameplay.LogicSystem.SecretPartner.Base.SecretPartnerSkill",
}) do
    Loader.AfterLoad(moduleName, function(value)
        installTableDataRowRepair(Game and Game.TableData, moduleName)
        return value
    end, 1000000, "cpdd.runtime-fix.table-rows-late." .. moduleName:gsub("[^%w]", "-"))
end

Loader.AfterLoad("Gameplay.Const.StringConst.StringConst", function(value, environment)
    local stringConst = getSymbol(value, environment, "StringConst")
    if type(stringConst) ~= "table" or stringConst.__cpddRuntimeFixV1 then
        return value
    end

    stringConst.__cpddRuntimeFixV1 = true
    local originalGet = assert(stringConst.Get)

    stringConst.Get = function(key, ...)
        local replacement = stringConstOverrides[key]
        if replacement ~= nil then
            if select("#", ...) > 0 then
                local formatOk, formatted = pcall(string.format, replacement, ...)
                if formatOk then
                    return formatted
                end
                report("StringConst override format failed key=" .. tostring(key))
            end
            return replacement
        end
        local getOk, result = pcall(originalGet, key, ...)
        if not getOk then
            report("StringConst.Get failed key=" .. tostring(key) .. " error=" .. tostring(result))
            return tostring(key or "")
        end
        return repairLiveString("StringConst", key, key, result)
    end

    return value
end, 1000000, "cpdd.runtime-fix.string-const")

local numberWordsUnderTwenty = {
    "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine",
    "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen",
    "Seventeen", "Eighteen", "Nineteen",
}
local numberWordsTens = {
    [2] = "Twenty",
    [3] = "Thirty",
    [4] = "Forty",
    [5] = "Fifty",
    [6] = "Sixty",
    [7] = "Seventy",
    [8] = "Eighty",
    [9] = "Ninety",
}

local function englishNumberUnderHundred(num)
    if num < 20 then
        return numberWordsUnderTwenty[num + 1]
    end

    local tens = math.floor(num / 10)
    local ones = num % 10
    local result = numberWordsTens[tens]
    if ones ~= 0 then
        result = result .. " " .. numberWordsUnderTwenty[ones + 1]
    end
    return result
end

local function englishNumberUnderThousand(num)
    if num < 100 then
        return englishNumberUnderHundred(num)
    end

    local hundreds = math.floor(num / 100)
    local remainder = num % 100
    local result = numberWordsUnderTwenty[hundreds + 1] .. " Hundred"
    if remainder ~= 0 then
        result = result .. " " .. englishNumberUnderHundred(remainder)
    end
    return result
end

local function englishNumber(num)
    if type(num) ~= "number" or num < 0 or num >= 10000 or math.floor(num) ~= num then
        return num
    end
    if num < 1000 then
        return englishNumberUnderThousand(num)
    end

    local thousands = math.floor(num / 1000)
    local remainder = num % 1000
    local result = englishNumberUnderThousand(thousands) .. " Thousand"
    if remainder ~= 0 then
        result = result .. " " .. englishNumberUnderThousand(remainder)
    end
    return result
end

Loader.AfterLoad("Gameplay.LogicSystem.Utils.HUDUtils", function(value, environment)
    ensureGameTableDataRowRepair("HUDUtils")
    local hudUtils = getSymbol(value, environment, "HUDUtils")
    if type(hudUtils) ~= "table" or hudUtils.__cpddRuntimeFixV1 then
        return value
    end

    hudUtils.__cpddRuntimeFixV1 = true
    hudUtils.NumberToChinese = englishNumber
    report("installed English HUD number formatter")
    return value
end, 1000000, "cpdd.runtime-fix.hud-number-format")

-- FamilySystem builds seat labels by concatenating NumberToChinese(index)
-- with the localized suffix. After the global English number formatter that
-- produces labels such as "ThreeSeat". Return the lore-facing ordinal names
-- directly for every authored family seat instead.
Loader.AfterLoad("Gameplay.LogicSystem.Family.FamilySystem", function(value, environment)
    local familySystem = getSymbol(value, environment, "FamilySystem")
    if type(familySystem) ~= "table"
        or familySystem.__cpddEnglishFamilySeatName == VERSION
    then
        return value
    end

    local originalGetSeatName = familySystem.GetSeatName
    if type(originalGetSeatName) ~= "function" then
        return value
    end

    local familySeatNames = {
        [2] = "Second Seat",
        [3] = "Third Seat",
        [4] = "Fourth Seat",
        [5] = "Fifth Seat",
        [6] = "Sixth Seat",
        [7] = "Seventh Seat",
        [8] = "Eighth Seat",
        [9] = "Ninth Seat",
        [10] = "Tenth Seat",
        [11] = "Eleventh Seat",
        [12] = "Twelfth Seat",
        [13] = "Thirteenth Seat",
        [14] = "Fourteenth Seat",
    }
    familySystem.GetSeatName = function(self, index)
        local replacement = familySeatNames[index]
        if replacement ~= nil then
            return replacement
        end
        return originalGetSeatName(self, index)
    end
    familySystem.__cpddEnglishFamilySeatName = VERSION
    report("installed English family-seat ordinal names")
    return value
end, 1000000, "cpdd.runtime-fix.family-seat-names")

-- The Style detail section was authored for short Chinese labels. Its two
-- sibling widgets begin too close to the left edge, so longer English style
-- names are clipped by the parent panel. Move the complete title and progress
-- section together, preserving the row spacing and rank bars.
Loader.AfterLoad(
    "Gameplay.LogicSystem.Fashion.FashionMain.UIPanel.FashionMain_Panel.ChangeWidget.Fashion_DetailExpand",
    function(value, environment)
        local fashionDetail = getSymbol(value, environment, "Fashion_DetailExpand")
        if type(fashionDetail) ~= "table"
            or fashionDetail.__cpddEnglishStyleLayout == VERSION
        then
            return value
        end

        local function reflowStyleDetails(owner)
            if not runtimeUIRepairEnabled() then
                return false
            end

            local view = owner and owner.view
            local root = owner and (owner.userWidget or owner.widget)
            local changed = false
            for _, widgetName in ipairs({
                "StyleText",
                "WBP_FashionChange_StyleProgress",
            }) do
                local widget = getNamedWidget(view, widgetName)
                    or getNamedWidget(root, widgetName)
                if widget ~= nil then
                    local ok = pcall(function()
                        if widget.SetRenderTranslation ~= nil then
                            widget:SetRenderTranslation(sceneTextVector2D(48, 0))
                            changed = true
                        end
                        if widget.InvalidateLayoutAndVolatility ~= nil then
                            widget:InvalidateLayoutAndVolatility()
                        end
                    end)
                    changed = ok or changed
                end
            end
            return changed
        end

        local originalRefreshStyle = fashionDetail.RefreshStyle
        if type(originalRefreshStyle) ~= "function" then
            return value
        end

        fashionDetail.RefreshStyle = function(self, ...)
            local results = { originalRefreshStyle(self, ...) }
            reflowStyleDetails(self)
            scheduleRepairBurst(self, reflowStyleDetails, 0.50)
            return unpack(results)
        end
        fashionDetail.__cpddEnglishStyleLayout = VERSION
        report("installed English Style detail horizontal reflow")
        return value
    end,
    1000000,
    "cpdd.runtime-fix.fashion-style-layout"
)

Loader.AfterLoad("Gameplay.LogicSystem.Reminder.PlayerInfo.PowerItemSpecial", function(value, environment)
    ensureGameTableDataRowRepair("PowerItemSpecial")
    local powerItem = getSymbol(value, environment, "PowerItemSpecial")
    if type(powerItem) ~= "table" or powerItem.__cpddRuntimeFixV1 then
        return value
    end

    powerItem.__cpddRuntimeFixV1 = true
    local originalRefresh = assert(powerItem.Refresh)
    function powerItem:Refresh(...)
        local results = { originalRefresh(self, ...) }
        if runtimeUIRepairEnabled() then
            translateViewTextWidgets(self.view, self.userWidget)
        end
        return unpack(results)
    end

    report("installed Beyonder Rating reminder label fix")
    return value
end, 1000000, "cpdd.runtime-fix.power-rating-label")

Loader.AfterLoad("Gameplay.LogicSystem.NewHeadInfo.HeadInfoUI.HeadInfoName", function(value, environment)
    ensureGameTableDataRowRepair("HeadInfoName")
    local headInfoName = getSymbol(value, environment, "HeadInfoName")
    if type(headInfoName) ~= "table" or headInfoName.__cpddRuntimeFixV1 then
        return value
    end

    headInfoName.__cpddRuntimeFixV1 = true
    local originalGetEntityName = assert(headInfoName.getEntityName)
    local originalOnHeadNameChanged = assert(headInfoName.OnHeadNameChanged)

    function headInfoName:getEntityName(entity)
        return translateVisibleText(originalGetEntityName(self, entity))
    end

    function headInfoName:OnHeadNameChanged(name)
        return originalOnHeadNameChanged(self, translateVisibleText(name))
    end

    report("installed translated overhead NPC names")
    return value
end, 1000000, "cpdd.runtime-fix.head-info-name")

Loader.AfterLoad("Gameplay.LogicSystem.Race.WorldWidget.RaceTrace_Widget", function(value, environment)
    local raceWidget = getSymbol(value, environment, "RaceTrace_Widget")
    if type(raceWidget) ~= "table" or raceWidget.__cpddRuntimeFixV1 then
        return value
    end

    local mathLibrary = getSymbol(value, environment, "KismetMathLibrary")
    if type(mathLibrary) ~= "table" then
        local ok, imported = pcall(import, "KismetMathLibrary")
        if ok then
            mathLibrary = imported
        end
    end
    if type(mathLibrary) ~= "table" or type(mathLibrary.Vector_Distance) ~= "function" then
        report("could not install RaceTrace meter fix: KismetMathLibrary unavailable")
        return value
    end

    raceWidget.__cpddRuntimeFixV1 = true
    function raceWidget:UpdateDistance()
        if not Game or not Game.me or not self.checkpointPos then
            return
        end

        local playerPos = Game.me.CppEntity:KAPI_GetLocation()
        local dist = mathLibrary.Vector_Distance(playerPos, self.checkpointPos)
        local distMeter = math.floor(dist / 100)
        local distanceWidget = self.view and self.view.Text_Distance
        if distanceWidget
            and (self.__cpddDistanceWidget ~= distanceWidget
                or self.__cpddLastDistanceMeter ~= distMeter)
        then
            self.__cpddDistanceWidget = distanceWidget
            self.__cpddLastDistanceMeter = distMeter
            distanceWidget:SetText(tostring(distMeter) .. "m")
        end
    end

    report("installed RaceTrace meter fix")
    return value
end, 1000000, "cpdd.runtime-fix.racetrace-meter")

Loader.AfterLoad("Gameplay.LogicSystem.Tips.TipsSystem", function(value, environment)
    local tipsSystem = getSymbol(value, environment, "TipsSystem")
    if type(tipsSystem) ~= "table" or tipsSystem.__cpddRuntimeFixV1 then
        return value
    end

    tipsSystem.__cpddRuntimeFixV1 = true
    local originalParse = assert(tipsSystem._parseTipsDataSections)

    function tipsSystem:_parseTipsDataSections(tipsId)
        if tipsId == CIRCUIT_BREAKER_TIPS_ID then
            return {
                {
                    Content = { CIRCUIT_BREAKER_TEXT },
                },
            }
        end
        return originalParse(self, tipsId)
    end

    return value
end, 1000000, "cpdd.runtime-fix.circuit-breaker-content")

Loader.AfterLoad("Gameplay.LogicSystem.Login.LoginServerSelect_Panel", function(value, environment)
    local panel = getSymbol(value, environment, "LoginServerSelect_Panel")
    if type(panel) ~= "table" or panel.__cpddRuntimeFixV1 then
        return value
    end

    panel.__cpddRuntimeFixV1 = true
    function panel:on_Btn_Info_Clicked()
        Game.TipsSystem:ShowTips(CIRCUIT_BREAKER_TIPS_ID, self.view.Btn_Info:GetCachedGeometry())
    end

    return value
end, 1000000, "cpdd.runtime-fix.circuit-breaker-button")

Loader.AfterLoad("Gameplay.LogicSystem.SkillCustomizer.SkillBuffDescUtils", function(value, environment)
    local utils = getSymbol(value, environment, "SkillBuffDescUtils")
    if type(utils) ~= "table" or utils.__cpddRuntimeFixV1 then
        return value
    end

    utils.__cpddRuntimeFixV1 = true
    local originalPostProcessingString = assert(utils.PostProcessingString)
    local originalAssembleDescString = assert(utils.AssembleDescString)

    function utils:PostProcessingString(inString, rtbOverWrite, id, level, descType, originalType, descContext)
        local result = originalPostProcessingString(self, inString, rtbOverWrite, id, level, descType, originalType, descContext)
        if id ~= 86071030 or type(result) ~= "string" then
            return result
        end

        local spellFieldIds = { 811710303, 811710304 }
        local replacementIndex = 0
        result = result:gsub("spellfielddisc%(%s*82071030%s*%)", function()
            replacementIndex = replacementIndex + 1
            local spellFieldId = spellFieldIds[replacementIndex] or spellFieldIds[#spellFieldIds]
            local helper = getSymbol(nil, environment, "DescFormulaHelper")
            if type(helper) == "table" and type(helper.GenerateDesc) == "function" then
                local ok, generated = pcall(helper.GenerateDesc, spellFieldId, level, utils.DescType.SpellField, originalType, descContext)
                if ok and generated ~= nil and generated ~= "" then
                    return tostring(generated)
                end
            end
            return "additional"
        end)
        result = result:gsub("NO_BUFF_NAME", "Star Sand Gathering")
        result = result:gsub("NO_SUCH_INFORMATION", "Each stack reduces Movement Speed.")
        return result
    end

    function utils:AssembleDescString(inString, values, rtbOverWrite, id, level, descType, originalType, descContext)
        local original = originalAssembleDescString(
            self, inString, values, rtbOverWrite, id, level,
            descType, originalType, descContext
        )
        if type(original) ~= "string" then
            return original
        end
        local translated = repairLiveString(
            "SkillBuffDescUtils", id, "AssembleDescString.return", original
        )
        runtimeMetrics.CaptureTranslationAssignment(
            self, "SkillBuffDescUtils", "SkillBuffDescUtils",
            "Description", original, translated
        )
        return translated
    end

    report("installed shared generated skill/buff-description translation")
    return value
end, 1000000, "cpdd.runtime-fix.star-sand-description")

Loader.AfterLoad("Gameplay.LogicSystem.SkillCustomizer.DescFormulaHelper", function(value, environment)
    local helper = getSymbol(value, environment, "DescFormulaHelper")
    if type(helper) ~= "table" or helper.__cpddGeneratedTipsRepair == VERSION then
        return value
    end
    local originalGenerateTipsDesc = helper.GenerateTipsDesc
    if type(originalGenerateTipsDesc) ~= "function" then
        return value
    end

    helper.GenerateTipsDesc = function(tipsString, markTag)
        local original = originalGenerateTipsDesc(tipsString, markTag)
        if type(original) ~= "string" then
            return original
        end
        local translated = repairLiveString(
            "DescFormulaHelper", "GenerateTipsDesc",
            "GenerateTipsDesc.return", original
        )
        runtimeMetrics.CaptureTranslationAssignment(
            nil, "DescFormulaHelper", "DescFormulaHelper",
            "TipsDescription", original, translated
        )
        return translated
    end
    helper.__cpddGeneratedTipsRepair = VERSION
    report("installed shared generated equipment-tip translation")
    return value
end, 1000000, "cpdd.runtime-fix.generated-equipment-tip-description")

local function installSkillDescriptionRepair(value, environment)
    local skillSystem = getSymbol(value, environment, "SkillCustomSystem")
    if type(skillSystem) ~= "table" or skillSystem.__cpddGeneratedTextRepair == VERSION then
        return false
    end

    local wrapped = 0
    for _, methodName in ipairs({
        "GenerateSkillDescNoRichText",
        "GenerateSkillBriefDesc",
        "GenerateSkillDecoText",
    }) do
        local original = skillSystem[methodName]
        if type(original) == "function" then
            skillSystem[methodName] = function(self, ...)
                local results = { original(self, ...) }
                if type(results[1]) == "string" then
                    results[1] = repairLiveString("SkillCustomSystem", select(1, ...), methodName, results[1])
                end
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    skillSystem.__cpddGeneratedTextRepair = VERSION
    if wrapped > 0 then
        report("installed generated skill-description repair")
    end
    return wrapped > 0
end

Loader.AfterLoad(
    "Gameplay.LogicSystem.SkillCustomizer.SkillCustomSystem",
    function(value, environment)
        installSkillDescriptionRepair(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.generated-skill-description"
)

local function installViewMethodRepair(value, environment, symbolName, methodNames, source)
    local class = getSymbol(value, environment, symbolName)
    if type(class) ~= "table" then
        return false
    end

    local marker = "__cpddViewTextRepair_" .. VERSION
    if class[marker] then
        return true
    end

    local wrapped = 0
    for _, methodName in ipairs(methodNames) do
        local original = class[methodName]
        if type(original) == "function" then
            class[methodName] = function(self, ...)
                local results = { original(self, ...) }
                if runtimeUIRepairEnabled() then
                    -- Refresh methods can repaint serialized Blueprint text or
                    -- bind a different row to an existing component. Rescan on
                    -- the event itself; this remains bounded to this view and
                    -- does not restore the expensive global widget sweep.
                    local rootWidget = self and (self.userWidget or self.widget)
                    translateViewTextWidgets(self and self.view, rootWidget)
                end
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    class[marker] = true
    if wrapped > 0 then
        report("installed post-refresh widget repair for " .. source)
    end
    return wrapped > 0
end

local function installDataMethodRepair(value, environment, symbolName, methodNames, source)
    local class = getSymbol(value, environment, symbolName)
    if type(class) ~= "table" then
        return false
    end

    local marker = "__cpddDataTextRepair_" .. VERSION
    if class[marker] then
        return true
    end

    local wrapped = 0
    for _, methodName in ipairs(methodNames) do
        local original = class[methodName]
        if type(original) == "function" then
            class[methodName] = function(self, ...)
                if not runtimeUIRepairEnabled() then
                    return original(self, ...)
                end
                local argumentCount = select("#", ...)
                local arguments = { ... }
                for argumentIndex = 1, argumentCount do
                    local data = arguments[argumentIndex]
                    local fieldName = methodName .. ".argument" .. tostring(argumentIndex)
                    if type(data) == "string" then
                        local translated = repairLiveString(source, methodName, fieldName, data)
                        runtimeMetrics.CaptureDataAssignment(
                            self, source, symbolName, fieldName, data, translated, methodName
                        )
                        arguments[argumentIndex] = translated
                    elseif type(data) == "table" then
                        translateTableStrings(data, nil, {
                            component = self,
                            module = source,
                            class = symbolName,
                            record = methodName,
                        }, fieldName)
                    end
                end
                local results = { original(self, unpack(arguments, 1, argumentCount)) }
                -- Data-driven rows and tooltip blocks are reused. Their first
                -- refresh can contain a placeholder or an earlier item's text,
                -- so a per-instance "already repaired" flag leaves later CJK
                -- values untranslated and invisible to the detector. This is
                -- still event-driven: only the small component being refreshed
                -- is rescanned, never every widget on every frame.
                local rootWidget = self and (self.userWidget or self.widget)
                translateViewTextWidgets(self and self.view, rootWidget)
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    class[marker] = true
    if wrapped > 0 then
        report("installed rendered data repair for " .. source)
    end
    return wrapped > 0
end

runtimeMetrics.InstallEquipmentSpecialTextRepair = function(value, environment)
    local source = "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipSpecial"
    local className = "ItemTipsEquipSpecial"
    local class = getSymbol(value, environment, className)
    if type(class) ~= "table" or class.__cpddEquipmentSpecialTextRepair == VERSION then
        return type(class) == "table"
    end

    local originalSetData = class.SetData
    if type(originalSetData) ~= "function" then
        return false
    end

    class.SetData = function(self, suitName, suitBrief, suitDesc, story, uniqueData, index)
        if not runtimeUIRepairEnabled() then
            return originalSetData(self, suitName, suitBrief, suitDesc, story, uniqueData, index)
        end

        local originalName, originalBrief, originalDesc, originalStory = suitName, suitBrief, suitDesc, story
        suitName = repairLiveString(source, index, "SuitName", suitName)
        suitBrief = repairLiveString(source, index, "SuitBrief", suitBrief)
        suitDesc = repairLiveString(source, index, "SuitDesc", suitDesc)
        story = repairLiveString(source, index, "Story", story)

        runtimeMetrics.CaptureTranslationAssignment(self, source, className, "SuitName", originalName, suitName)
        runtimeMetrics.CaptureTranslationAssignment(self, source, className, "SuitBrief", originalBrief, suitBrief)
        runtimeMetrics.CaptureTranslationAssignment(self, source, className, "SuitDesc", originalDesc, suitDesc)
        runtimeMetrics.CaptureTranslationAssignment(self, source, className, "Story", originalStory, story)

        local results = { originalSetData(self, suitName, suitBrief, suitDesc, story, uniqueData, index) }
        local context = {
            panel = className,
            module = source,
            class = className,
            pass = "item-tips-set-data",
        }
        local view = self and self.view
        if type(view) == "table" then
            translateTextWidget(view.Text_Name, context)
            translateTextWidget(view.Text_Detail, context)
            translateTextWidget(view.Text_Story, context)
        end
        return unpack(results)
    end
    class.__cpddEquipmentSpecialTextRepair = VERSION
    report("installed authoritative ItemTipsEquipSpecial:SetData translation")
    return true
end

runtimeMetrics.InstallSealedSkillDescRepair = function(value, environment)
    local source = "Gameplay.LogicSystem.Sealed_2.SealedSystem"
    local className = "SealedSystem"
    local class = getSymbol(value, environment, className)
    if type(class) ~= "table" or class.__cpddSealedSkillDescRepair == VERSION then
        return type(class) == "table"
    end

    local originalGetDesc = class.GetSealedSkillDescText
    if type(originalGetDesc) ~= "function" then
        return false
    end

    class.GetSealedSkillDescText = function(self, skillList, sealedId, sealedGrade, knowledgeLevel)
        local original = originalGetDesc(self, skillList, sealedId, sealedGrade, knowledgeLevel)
        if not runtimeUIRepairEnabled() or type(original) ~= "string" then
            return original
        end

        -- Sealed descriptions are assembled after StringDB lookup and formula
        -- evaluation. Repair the generated result so every consumer (equip,
        -- promote, quick assembly, and item tips) receives the same English
        -- text, including descriptions whose CheckStar tokens became numbers.
        local translated = repairLiveString(
            source, sealedId, "GetSealedSkillDescText.return", original
        )
        runtimeMetrics.CaptureTranslationAssignment(
            self, source, className, "SkillDescription", original, translated
        )
        return translated
    end
    class.__cpddSealedSkillDescRepair = VERSION
    report("installed authoritative SealedSystem skill-description translation")
    return true
end

local function installGuildRoleRepair(value, environment)
    local guildSystem = getSymbol(value, environment, "GuildSystem")
    if type(guildSystem) ~= "table" or guildSystem.__cpddRoleTextRepair == VERSION then
        return false
    end

    local wrapped = 0
    for _, methodName in ipairs({ "RoleIDToRoleName", "GetOccupationText" }) do
        local original = guildSystem[methodName]
        if type(original) == "function" then
            guildSystem[methodName] = function(self, ...)
                local results = { original(self, ...) }
                if type(results[1]) == "string" then
                    results[1] = repairLiveString("GuildSystem", select(1, ...), methodName, results[1])
                end
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    guildSystem.__cpddRoleTextRepair = VERSION
    if wrapped > 0 then
        report("installed translated club-role names")
    end
    return wrapped > 0
end

local DIALOGUE_LINE_MAX = 42
local DIALOGUE_ROW_HEIGHT = 58
local DIALOGUE_VISIBLE = 4
do
    local ok, visibility = pcall(function()
        return import("ESlateVisibility")
    end)
    if ok and visibility ~= nil then
        DIALOGUE_VISIBLE = visibility.SelfHitTestInvisible or visibility.Visible or DIALOGUE_VISIBLE
    end
end

local function scheduleRepairAfter(self, delay, repair)
    if self == nil or type(repair) ~= "function" then
        return false
    end
    local ok, addTimer = pcall(function()
        return self.AddTimerWithFunction
    end)
    if not ok or type(addTimer) ~= "function" then
        return false
    end
    return pcall(addTimer, self, delay, 1, function()
        pcall(repair, self)
    end)
end

local pendingRepairBursts = setmetatable({}, { __mode = "k" })
local function scheduleRepairBurst(self, repair, finalDelay)
    if self == nil or type(repair) ~= "function" then
        return false
    end
    local ok, addTimer = pcall(function()
        return self.AddTimerWithFunction
    end)
    if not ok or type(addTimer) ~= "function" then
        return false
    end

    local pending = pendingRepairBursts[self]
    if pending == nil then
        pending = {}
        pendingRepairBursts[self] = pending
    elseif pending[repair] then
        return false
    end
    pending[repair] = true

    local function clearPending()
        pending[repair] = nil
        if next(pending) == nil then
            pendingRepairBursts[self] = nil
        end
    end

    local scheduledOk, scheduled = pcall(addTimer, self, 0.01, 1, function()
        pcall(repair, self)
        local finalOk, finalScheduled = pcall(addTimer, self, finalDelay or 0.50, 1, function()
            pcall(repair, self)
            clearPending()
        end)
        if not finalOk or finalScheduled == false then
            clearPending()
        end
    end)
    if not scheduledOk or scheduled == false then
        clearPending()
        return false
    end
    return true
end

local function normalizeDialogueWhitespace(value)
    if type(value) ~= "string" then
        return value
    end
    value = value:gsub("%s*\r?\n%s*", " ")
    value = value:gsub("[ \t]+", " ")
    return value:match("^%s*(.-)%s*$")
end

local function dialogueVisibleLength(value)
    if type(value) ~= "string" then
        return 0
    end
    local plain = value:gsub("<.->", "")
    local ok, length = pcall(function()
        return utf8.len(plain)
    end)
    return ok and length or #plain
end

local function revealDialogueRows(self)
    local talkWidget = self and self.userWidget
    if talkWidget == nil then
        return false
    end
    local changed = false
    -- The native printer already assigns one line to each RichTextBlock. Do
    -- not enable RichText auto-wrap as that wraps the foreground and shadow
    -- layers independently and produces the narrow duplicate text tower.
    for _, widgetName in ipairs({
        "RTB_TalkContent_Back_lua", "RTB_TalkContent_lua",
        "RTB_TalkContent2_Back_lua", "RTB_TalkContent2_lua",
        "RTB_TalkContent3_Back_lua", "RTB_TalkContent3_lua",
    }) do
        pcall(function()
            local widget = getNamedWidget(talkWidget, widgetName)
            if widget ~= nil then
                if widget.SetAutoWrapText ~= nil then
                    widget:SetAutoWrapText(false)
                end
                changed = true
            end
        end)
    end

    -- Only reveal the third row when it was actually bound. Never force both
    -- the CanvasPanel and VerticalBox layout variants visible: some cooked
    -- dialogue widgets contain both and doing so renders the same text twice.
    if self.__cpddDialogueHasThirdLine then
        for _, widgetName in ipairs({
            "RTB_TalkContent3_Back_lua", "RTB_TalkContent3_lua",
        }) do
            pcall(function()
                local widget = getNamedWidget(talkWidget, widgetName)
                if widget ~= nil then
                    widget:SetVisibility(DIALOGUE_VISIBLE)
                    if widget.SetRenderOpacity ~= nil then
                        widget:SetRenderOpacity(1)
                    end
                end
            end)
        end

        pcall(function()
            local canvasRow = getNamedWidget(talkWidget, "Canvas_Content03")
            local sizeRow = nil
            if canvasRow ~= nil then
                canvasRow:SetVisibility(DIALOGUE_VISIBLE)
                if canvasRow.SetRenderOpacity ~= nil then
                    canvasRow:SetRenderOpacity(1)
                end
                sizeRow = getNamedWidget(talkWidget, "SizeBox_3")
            else
                sizeRow = getNamedWidget(talkWidget, "SizeBox_2")
            end
            if sizeRow ~= nil then
                sizeRow:SetVisibility(DIALOGUE_VISIBLE)
                if sizeRow.SetRenderOpacity ~= nil then
                    sizeRow:SetRenderOpacity(1)
                end
                if sizeRow.SetHeightOverride ~= nil then
                    sizeRow:SetHeightOverride(DIALOGUE_ROW_HEIGHT)
                end
            end
        end)
    end
    return changed
end

local function reportDialogueThirdRowState(self)
    if self == nil or self.__cpddDialogueThirdRowReported == VERSION then
        return
    end
    self.__cpddDialogueThirdRowReported = VERSION
    local talkWidget = self.userWidget
    if talkWidget == nil then
        return
    end
    local states = {}
    for _, widgetName in ipairs({
        "Canvas_Content03", "SizeBox_2", "SizeBox_3",
        "RTB_TalkContent3_Back_lua", "RTB_TalkContent3_lua",
    }) do
        pcall(function()
            local widget = getNamedWidget(talkWidget, widgetName)
            if widget ~= nil then
                local visibility = widget.GetVisibility and tostring(widget:GetVisibility()) or "?"
                local opacity = widget.GetRenderOpacity and tostring(widget:GetRenderOpacity()) or "?"
                states[#states + 1] = widgetName .. "=" .. visibility .. "/" .. opacity
            end
        end)
    end
    report("dialogue third-row live state " .. table.concat(states, ","))
end

local function bindDialogueRows(self)
    local talkWidget = self and self.userWidget
    local printer = self and self.ContentPrinter
    if talkWidget == nil or printer == nil then
        return false
    end

    local widgetNames = {
        "RTB_TalkContent_Back_lua",
        "RTB_TalkContent_lua",
        "RTB_TalkContent2_Back_lua",
        "RTB_TalkContent2_lua",
        "RTB_TalkContent3_Back_lua",
        "RTB_TalkContent3_lua",
    }
    local widgets = {}
    local missing = {}
    for index, widgetName in ipairs(widgetNames) do
        widgets[index] = getNamedWidget(talkWidget, widgetName)
        if widgets[index] == nil then
            missing[#missing + 1] = widgetName
        end
    end

    local hasCoreRows = widgets[1] ~= nil and widgets[2] ~= nil
        and widgets[3] ~= nil and widgets[4] ~= nil
    local hasThirdLine = widgets[5] ~= nil and widgets[6] ~= nil
    self.__cpddDialogueHasThirdLine = hasThirdLine

    local ok = hasCoreRows and pcall(function()
        printer:BindWidget(
            widgets[1], widgets[2], widgets[3],
            widgets[4], widgets[5], widgets[6]
        )
        printer.LineMaxCharCount = DIALOGUE_LINE_MAX
        printer:SetEnableTwoLinePrinter(true)
    end)
    self.__cpddDialogueRowsBound = ok and VERSION or nil
    if #missing > 0 and self.__cpddDialogueWidgetLookupReported ~= VERSION then
        self.__cpddDialogueWidgetLookupReported = VERSION
        report("dialogue widget lookup missing " .. table.concat(missing, ","))
    elseif #missing == 0 and self.__cpddDialogueWidgetLookupReported ~= VERSION then
        self.__cpddDialogueWidgetLookupReported = VERSION
        report("dialogue third row bound from the live widget tree")
    end
    revealDialogueRows(self)
    return ok and hasThirdLine
end

local function configureDialogueLineCapacity(self, content)
    local printer = self and self.ContentPrinter
    if printer == nil then
        return DIALOGUE_LINE_MAX
    end
    local rows = self.__cpddDialogueHasThirdLine and 3 or 2
    local visibleLength = math.max(1, dialogueVisibleLength(content))
    -- Distribute the complete entry over the rows that are really available.
    -- This prevents the native printer from assigning an unbound third-row
    -- remainder, while retaining its foreground/shadow typewriter behavior.
    local lineCapacity = math.max(DIALOGUE_LINE_MAX, math.ceil(visibleLength / rows))
    printer.LineMaxCharCount = lineCapacity
    return lineCapacity
end

local function installDialogueTalkRepair(value, environment)
    local dialogueTalk = getSymbol(value, environment, "DialogueTalk")
    if type(dialogueTalk) ~= "table" or dialogueTalk.__cpddEnglishLayoutRepair == VERSION then
        return false
    end

    local originalInitUIData = dialogueTalk.InitUIData
    local originalShowContent = dialogueTalk.ShowContent
    if type(originalInitUIData) ~= "function" or type(originalShowContent) ~= "function" then
        return false
    end

    dialogueTalk.InitUIData = function(self, ...)
        local results = { originalInitUIData(self, ...) }
        if runtimeUIRepairEnabled() then
            -- InitUIData may replace the native printer or widget tree on a
            -- reused panel. Rebind once for the new UI, then let ShowContent
            -- reuse that binding for every dialogue entry.
            self.__cpddDialogueRowsBound = nil
            self.__cpddDialogueVisibleTextRepaired = nil
            bindDialogueRows(self)
        end
        return unpack(results)
    end

    dialogueTalk.ShowContent = function(self, content, ...)
        if not runtimeUIRepairEnabled() then
            return originalShowContent(self, content, ...)
        end
        if self.__cpddDialogueRowsBound ~= VERSION then
            bindDialogueRows(self)
        end
        local normalizedContent = normalizeDialogueWhitespace(content)
        self.__cpddDialogueWrappedContent = normalizedContent
        configureDialogueLineCapacity(self, normalizedContent)
        local results = { originalShowContent(self, normalizedContent, ...) }
        -- The Blueprint's BP_SetFontType call runs at the end of the original
        -- method and can refresh the outer row wrapper again on the next UI
        -- tick. Repair now, then use one coalesced retry burst after the
        -- Blueprint updates land.
        revealDialogueRows(self)
        scheduleRepairBurst(self, revealDialogueRows, 0.50)
        scheduleRepairAfter(self, 0.55, reportDialogueThirdRowState)
        if self.__cpddDialogueVisibleTextRepaired ~= VERSION then
            translateViewTextWidgets(self and self.view, self and self.userWidget)
            self.__cpddDialogueVisibleTextRepaired = VERSION
        end
        return unpack(results)
    end

    dialogueTalk.__cpddEnglishLayoutRepair = VERSION
    report("installed dynamic multi-row English dialogue layout")
    return true
end

local function setLayeredDialogueLabel(owner, text)
    if owner == nil then
        return false
    end

    local changed = false
    local ok = pcall(function()
        owner:SetText(text)
    end)
    changed = changed or ok

    for _, fieldName in ipairs({ "Text_lua", "Text2_lua" }) do
        local fieldOk = pcall(function()
            local widget = owner[fieldName]
            if widget ~= nil then
                widget:SetText(text)
                changed = true
            end
        end)
        changed = changed or fieldOk
    end

    -- These Blueprint components can contain additional nested labels. Run
    -- the normal bootstrap text pass as well so no other Chinese caption is
    -- left behind when the component refreshes.
    translateViewTextWidgets(nil, owner)
    return changed
end

runtimeFixes.setNamedWidgetText = function(owner, widgetName, text)
    if owner == nil then
        return false
    end

    local widget = getNamedWidget(owner, widgetName)
    if widget == nil then
        return false
    end

    local changed = false
    local setOk = pcall(function()
        widget:SetText(text)
    end)
    changed = changed or setOk

    -- Some cooked KGTextBlocks retain their serialized Text property after
    -- BP_SetType. Update both representations and synchronize the Slate copy.
    local propertyOk = pcall(function()
        widget.Text = text
    end)
    changed = changed or propertyOk
    pcall(function()
        if widget.SynchronizeProperties ~= nil then
            widget:SynchronizeProperties()
        end
    end)
    pcall(function()
        if widget.InvalidateLayoutAndVolatility ~= nil then
            widget:InvalidateLayoutAndVolatility()
        end
    end)
    return changed
end

runtimeFixes.setPanelWidgetText = function(self, widgetName, text)
    local changed = false
    local view = self and self.view
    if view ~= nil then
        local widget = getNamedWidget(view, widgetName)
        if widget ~= nil then
            changed = pcall(function()
                widget:SetText(text)
            end) or changed
        end
    end
    return runtimeFixes.setNamedWidgetText(
        self and (self.userWidget or self.widget), widgetName, text
    ) or changed
end

runtimeFixes.translateNamedContainers = function(view, root, names)
    local repaired = 0
    local seen = setmetatable({}, { __mode = "k" })
    for _, name in ipairs(names) do
        local container = getNamedWidget(view, name) or getNamedWidget(root, name)
        if container ~= nil and not seen[container] then
            seen[container] = true
            repaired = repaired + translateViewTextWidgets(nil, container)
        end
    end
    return repaired
end

runtimeFixes.repairSkillHeaderWidget = function(widget)
    if widget == nil then
        return false
    end
    local changed = false
    changed = runtimeFixes.setNamedWidgetText(widget, "Text_Recommend", "Recommended Builds") or changed
    changed = runtimeFixes.setNamedWidgetText(widget, "Text_Extra", "My Builds") or changed
    changed = runtimeFixes.setNamedWidgetText(widget, "Text_BeStrong", "Improve") or changed
    -- Launch 1.1 also registers the recommended caption under its cooked
    -- Blueprint name instead of the generated Lua alias.
    changed = runtimeFixes.setNamedWidgetText(widget, "KGTextBlock_54", "Recommended Builds") or changed
    runtimeFixes.translateNamedContainers(nil, widget, {
        "Canvas_BeStrong", "Canvas_Extraordinarily", "Canvas_Recommend", "HB_Btn",
    })
    translateViewTextWidgets(nil, widget)
    return changed
end

runtimeFixes.skillImproveRepairLogged = false

runtimeFixes.reportSkillImproveRepair = function(self)
    if runtimeFixes.skillImproveRepairLogged then
        return
    end
    runtimeFixes.skillImproveRepairLogged = true

    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    local widget = getNamedWidget(view, "Text_BeStrong")
        or getNamedWidget(root, "Text_BeStrong")
    if widget == nil then
        local visited = setmetatable({}, { __mode = "k" })
        local function inspect(candidate)
            walkWidgetDescendants(candidate, visited, function(descendant)
                if widget ~= nil then
                    return
                end
                local ok, value = pcall(function()
                    return tostring(descendant:GetText())
                end)
                if ok and (value == "Improve" or value == "我要变强" or value == "要变强") then
                    widget = descendant
                end
            end)
        end
        inspect(getNamedWidget(view, "Canvas_BeStrong"))
        inspect(getNamedWidget(root, "Canvas_BeStrong"))
        if type(view) == "table" then
            for _, candidate in pairs(view) do
                inspect(candidate)
            end
        end
    end
    local value = "<not found>"
    if widget ~= nil then
        value = "<unreadable>"
        pcall(function()
            value = tostring(widget:GetText())
        end)
    end
    report("Improve caption verification found=" .. tostring(widget ~= nil) .. " value=" .. tostring(value))
end

runtimeFixes.repairSkillHeaderLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.setPanelWidgetText(self, "Text_Recommend", "Recommended Builds")
    runtimeFixes.setPanelWidgetText(self, "Text_Extra", "My Builds")
    runtimeFixes.setPanelWidgetText(self, "Text_BeStrong", "Improve")
    runtimeFixes.translateNamedContainers(view, root, {
        "Canvas_BeStrong", "Canvas_Extraordinarily", "Canvas_Recommend", "HB_Btn",
    })
    translateViewTextWidgets(view, root)
    runtimeFixes.repairSkillHeaderWidget(root)
    scheduleRepairAfter(self, 3.00, runtimeFixes.reportSkillImproveRepair)
end

runtimeFixes.repairEmbeddedSkillHeaderLabels = function(self)
    if self == nil then
        return
    end
    local view = self.view
    local root = self.userWidget or self.widget
    local header = getNamedWidget(view, "WBP_Skill_BeStrong_Btn")
        or getNamedWidget(view, "WBP_Skill_BeStrong_Btn_lua")
        or getNamedWidget(root, "WBP_Skill_BeStrong_Btn")
        or getNamedWidget(root, "WBP_Skill_BeStrong_Btn_lua")
    runtimeFixes.translateNamedContainers(view, header or root, {
        "Canvas_BeStrong", "Canvas_Extraordinarily", "Canvas_Recommend", "HB_Btn",
    })
    runtimeFixes.repairSkillHeaderWidget(header)
end

runtimeFixes.repairDynamicPanelLabels = function(self)
    if self == nil then
        return
    end
    translateViewTextWidgets(self.view, self.userWidget or self.widget)
end

runtimeFixes.repairSkillCommonLabels = function(self)
    local view = self and self.view
    if view == nil then
        return
    end

    -- These two footer labels belong to the parent panel, not to the
    -- Skill_BeStrong_Btn component.
    runtimeFixes.setNamedWidgetText(view, "Text_WoodenPost", "Training Dummy")
    local oneClickPage = nil
    pcall(function()
        oneClickPage = view.WBP_Skill_OneClick_Page
    end)
    runtimeFixes.setNamedWidgetText(oneClickPage, "Text_Content", "One-Click Assist")

    -- BP_SetType on the embedded header can refresh all three captions after
    -- its Lua component returns. Repair the nested UserWidget from the parent
    -- as the final owner as well as through the component hook.
    runtimeFixes.repairEmbeddedSkillHeaderLabels(self)
    runtimeFixes.repairSkillHeaderLabels(self and self.WBP_Skill_BeStrong_BtnCom)
end

runtimeFixes.repairTalentLabels = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_Reset", "Reset All")
    runtimeFixes.repairEmbeddedSkillHeaderLabels(self)
end

runtimeFixes.repairEquipmentLabels = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_Equip", "Equipment Builds")
end

runtimeFixes.repairEquipmentReformUnlockText = function(self)
    local view = self and self.view
    local widget = getNamedWidget(view, "Text_LevelTips")
    if widget == nil then
        return false
    end

    local current = nil
    pcall(function()
        current = tostring(widget:GetText())
    end)
    if type(current) ~= "string" or current == "" then
        return false
    end

    -- CheckConfigLocked can supply either the static English StringDB value or
    -- the runtime override. Normalize both paths after the native page refresh
    -- and retain a manual break rather than relying on width-sensitive wrapping.
    local wrapped, replacements = current:gsub(
        "Affix inheritance is available%.%s*Remolding",
        "Affix inheritance is available.\nRemolding",
        1
    )
    if replacements == 0 then
        return false
    end

    pcall(function()
        if widget.SetAutoWrapText ~= nil then
            widget:SetAutoWrapText(false)
        end
    end)
    return runtimeFixes.setNamedWidgetText(view, "Text_LevelTips", wrapped)
end

runtimeFixes.repairBagLabels = function(self)
    local autoDecomposeButton = self and self.view and self.view.AutoDecomposeBtn
    runtimeFixes.setNamedWidgetText(autoDecomposeButton, "TB_Word", "Auto-Dismantle")
end

runtimeFixes.repairSchemePlanItemLabels = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_Tips", "In Use")
end

runtimeFixes.repairSchemeUseLabels = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_BtnName", "Use")
    runtimeFixes.setPanelWidgetText(self, "Text_Tips", "In Use")
    runtimeFixes.setPanelWidgetText(self, "Text_Use", "Use")
    runtimeFixes.setPanelWidgetText(self, "Text_Using", "In Use")
end

runtimeFixes.repairScreenshotLabel = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_Name", "Screenshot")
end

runtimeFixes.repairLoginActivityLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.setPanelWidgetText(self, "Text_FashionTitleDec_1", "Reward Preview")
    runtimeFixes.translateNamedContainers(view, root, {
        "Canvas_Reward", "Canvas_Title", "VB_MainTitle",
    })
    translateViewTextWidgets(view, root)
end

runtimeFixes.repairItemReceivedLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.setPanelWidgetText(self, "text_center_lua", "Claimed")
    runtimeFixes.translateNamedContainers(view, root, { "Canvas_Received" })
    translateViewTextWidgets(view, root)
end

runtimeFixes.repairDiceResultLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.translateNamedContainers(view, root, {
        "Canvas_ResultRoot", "Canvas_Content", "Canvas_GUI",
        "Canvas_SuccessText", "Canvas_BigSuccessText",
    })
    translateViewTextWidgets(view, root)
end

runtimeFixes.repairSkillUpgradeTipsLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.setPanelWidgetText(self, "Text_Title_2", "Next-Level Effect")
    runtimeFixes.translateNamedContainers(view, root, {
        "VB_Content", "SizeBox_Content", "ScrollBox_Content",
    })
    translateViewTextWidgets(view, root)
end

runtimeFixes.repairSecretPartnerLabels = function(self)
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    runtimeFixes.translateNamedContainers(view, root, {
        "PanelSlot", "Canvas_BaseAttribute", "Canvas_Content", "Canvas_Main",
    })
    translateViewTextWidgets(view, root)
end

runtimeFixes.lastHuntLabelVerificationLogged = false

runtimeFixes.repairLastHuntMyDataLabels = function(self)
    runtimeFixes.setPanelWidgetText(self, "Text_Debris01", "Submit to earn Hunt Progress")
    runtimeFixes.setPanelWidgetText(self, "Text_Debris01_1", "Submit to earn Hunt Progress")
    runtimeFixes.setPanelWidgetText(self, "Text_Schedule", "Current Progress:")
    runtimeFixes.setPanelWidgetText(self, "Text_Title01", "Kills")
    runtimeFixes.setPanelWidgetText(self, "Text_Title02", "Assists")
    runtimeFixes.setPanelWidgetText(self, "Text_Rank", "Leaderboard")
    local view = self and self.view
    local root = self and (self.userWidget or self.widget)
    local containerNames = {
        "Canvas_MyData", "Canvas_Record", "Canvas_Task", "Canvas_RankBtn",
        "HB_MyData", "HB_Schedule", "HB_Task", "VB_MyData", "VB_Task",
        "VB_Tetx01", "VB_Tetx02", "VB_Tetx03",
    }
    runtimeFixes.translateNamedContainers(view, root, containerNames)
    translateViewTextWidgets(view, root)

    if not runtimeFixes.lastHuntLabelVerificationLogged then
        local expected = {
            ["Submit to earn Hunt Progress"] = true,
            ["Current Progress:"] = true,
            ["Kills"] = true,
            ["Assists"] = true,
            ["Leaderboard"] = true,
        }
        local observed = {}
        local unresolved = 0
        local visited = setmetatable({}, { __mode = "k" })
        local function inspect(widget)
            local ok, text = pcall(function()
                return tostring(widget:GetText())
            end)
            if not ok then
                return
            end
            if expected[text] then
                observed[text] = true
            elseif hasCjk and hasCjk(text) then
                unresolved = unresolved + 1
            end
        end
        for _, name in ipairs(containerNames) do
            walkWidgetDescendants(getNamedWidget(view, name) or getNamedWidget(root, name), visited, inspect)
        end
        local englishCount = 0
        for _ in pairs(observed) do
            englishCount = englishCount + 1
        end
        if englishCount == 5 then
            runtimeFixes.lastHuntLabelVerificationLogged = true
            report("Last Hunt painted-caption verification english=5 unresolvedChinese=" .. tostring(unresolved))
        end
    end
end

runtimeFixes.formatGroupedInteger = function(value)
    local number = tonumber(value)
    if number == nil then
        return tostring(value or "")
    end
    number = math.floor(number + 0.5)
    local sign = number < 0 and "-" or ""
    local grouped = tostring(math.abs(number))
    while true do
        local nextValue, replacements = grouped:gsub("^(%d+)(%d%d%d)", "%1,%2")
        grouped = nextValue
        if replacements == 0 then
            break
        end
    end
    return sign .. grouped
end

runtimeFixes.installLastHuntScoreFormatting = function(value, environment)
    local class = getSymbol(value, environment, "PVPLastHunt_Details_MyData")
    if type(class) ~= "table" or class.__cpddFullScoreFormatting == VERSION then
        return false
    end
    if type(class.FormatScoreTip) ~= "function" then
        return false
    end

    class.FormatScoreTip = function(_, number)
        return runtimeFixes.formatGroupedInteger(number)
    end
    class.__cpddFullScoreFormatting = VERSION
    report("installed full-number Last Hunt score formatting")
    return true
end

runtimeFixes.installCurrencyFormatting = function(value, environment)
    local class = getSymbol(value, environment, "CurrencyUtils")
    if type(class) ~= "table" or class.__cpddFullCurrencyFormatting == VERSION then
        return false
    end
    if type(class.GetGameMoneyFormat) ~= "function" then
        return false
    end

    -- Preserve the original numeric return type below its abbreviation
    -- threshold. Above it, return the complete grouped value instead of a
    -- locale suffix such as "127.6Ten Thousand".
    local verificationReported = false
    class.GetGameMoneyFormat = function(number)
        assert(type(number) == "number", "Num not a number")
        if number < 100000 then
            return number
        end
        local formatted = runtimeFixes.formatGroupedInteger(number)
        if not verificationReported then
            verificationReported = true
            report("shared currency formatting verification output=" .. formatted)
        end
        return formatted
    end
    class.__cpddFullCurrencyFormatting = VERSION
    report("installed full-number shared currency formatting")
    return true
end

runtimeFixes.installBattleStatisticsFormatting = function(value, environment)
    local class = getSymbol(value, environment, "DungeonBattleStatisticsSystem")
    if type(class) ~= "table" or class.__cpddFullBattleStatisticsFormatting == VERSION then
        return false
    end
    if type(class.GetFormatNumberString) ~= "function" then
        return false
    end

    -- The DPS meter has a separate formatter from CurrencyUtils. Its original
    -- implementation appends localized TEN_THOUSAND/AHUNDREDMILLION suffixes,
    -- which renders as literal English words after localization. Preserve its
    -- round-up behavior but always display the complete grouped value.
    class.GetFormatNumberString = function(_, number)
        number = tonumber(number) or 0
        return runtimeFixes.formatGroupedInteger(math.ceil(number))
    end
    class.__cpddFullBattleStatisticsFormatting = VERSION
    report("installed full-number DPS/statistics formatting")
    return true
end

runtimeMetrics.InstallPvpStatisticsFormatting = function(value, environment)
    local class = getSymbol(value, environment, "PVP_Stats_Item")
    if type(class) ~= "table" or class.__cpddFullPvpStatisticsFormatting == VERSION then
        return false
    end

    local originalSetAs6V6 = class.SetAs6V6
    local originalSetAs12V12 = class.SetAs12V12
    local originalSetAsChampion = class.SetAsChampion
    if type(originalSetAs6V6) ~= "function"
        and type(originalSetAs12V12) ~= "function"
        and type(originalSetAsChampion) ~= "function"
    then
        return false
    end

    -- Several PVP result screens share this row class. The 12v12 and champion
    -- paths abbreviate values above 10,000 with TEN_THOUSAND, and some 6v6
    -- result/history layouts fall through to the champion path. Re-render all
    -- three row variants from their raw data so every mode receives exact,
    -- grouped integers while retaining its layout and best-stat highlights.
    local function refreshStatisticCells(self, data, maxData, gameMode, compactLayout)
        if type(data) ~= "table" or type(self.StatsDataComponents) ~= "table" then
            return false
        end

        local pvpSystem = Game and Game.PVPSystem
        local model = pvpSystem and pvpSystem.model
        local keys = model and model.tabKeys and model.tabKeys[gameMode]
        if type(keys) ~= "table" then
            return false
        end

        for componentIndex, component in pairs(self.StatsDataComponents) do
            local componentKeys = keys[componentIndex]
            if type(componentKeys) == "table" and type(component) == "table"
                and type(component.Refresh) == "function"
            then
                local infoText = {}
                for _, key in pairs(componentKeys) do
                    local sourceValue = data[key]
                    local rawValue = tonumber(sourceValue)
                    local valueText = rawValue ~= nil
                        and runtimeFixes.formatGroupedInteger(rawValue)
                        or tostring(sourceValue or 0)
                    local isHigh = type(maxData) == "table"
                        and rawValue ~= nil
                        and tonumber(maxData[key]) == rawValue
                        and rawValue ~= 0
                    if isHigh then
                        valueText = string.format("<PVP_Data_Highlight>%s</>", valueText)
                    end
                    table.insert(infoText, valueText)
                end
                component:Refresh(
                    table.concat(infoText, "/", 1, #infoText),
                    compactLayout == true
                )
            end
        end

        return true
    end

    local pvpModes = Enum and Enum.EPVPGameModeData
    local installedMethods = 0
    local verifiedPaths = {}

    local function reportApplied(path, applied)
        if applied and not verifiedPaths[path] then
            verifiedPaths[path] = true
            report("PVP scoreboard number formatting applied path=" .. path)
        end
    end

    if type(originalSetAs6V6) == "function" then
        class.SetAs6V6 = function(self, data)
            local result = originalSetAs6V6(self, data)
            reportApplied(
                "6v6",
                refreshStatisticCells(
                    self, data, nil, pvpModes and pvpModes.TEAM6V6, true
                )
            )
            return result
        end
        installedMethods = installedMethods + 1
    end

    if type(originalSetAs12V12) == "function" then
        class.SetAs12V12 = function(self, data, index, maxData, maxIndex, bOtherSide, bEndGameStats)
            local result = originalSetAs12V12(
                self, data, index, maxData, maxIndex, bOtherSide, bEndGameStats
            )
            local gameMode = self.otherInfo and self.otherInfo.Mode
                or (pvpModes and pvpModes.TEAM12V12)
            reportApplied(
                "12v12",
                refreshStatisticCells(self, data, maxData, gameMode, false)
            )
            return result
        end
        installedMethods = installedMethods + 1
    end

    if type(originalSetAsChampion) == "function" then
        class.SetAsChampion = function(self, data, index, maxData, maxIndex, bOtherSide, bEndGameStats)
            local result = originalSetAsChampion(
                self, data, index, maxData, maxIndex, bOtherSide, bEndGameStats
            )
            reportApplied(
                "fallback",
                refreshStatisticCells(
                    self, data, maxData,
                    pvpModes and pvpModes.CHAMPION_GROUP_BATTLE, false
                )
            )
            return result
        end
        installedMethods = installedMethods + 1
    end

    class.__cpddFullPvpStatisticsFormatting = VERSION
    report(
        "installed full-number PVP scoreboard formatting methods="
        .. tostring(installedMethods)
    )
    return true
end

local function repairDialoguePanelLabels(self)
    local view = self and self.view
    if type(view) ~= "table" then
        return
    end

    setLayeredDialogueLabel(view.WBP_NPCReviewBtn, "Review")

    local skipOwner = view.WBP_Skip
    if skipOwner ~= nil then
        local ok, nested = pcall(function()
            return skipOwner.WBP_NPCBtnText_lua
        end)
        setLayeredDialogueLabel(ok and nested or skipOwner, "Skip")
    end
end

local function repairDialogueSkipLabels(self)
    local view = self and self.view
    if type(view) ~= "table" then
        return
    end
    setLayeredDialogueLabel(view.WBP_NPCBtnText_lua, "Skip")
end

local function installDialogueControlRepair(value, environment, symbolName, methodNames, repair, source)
    local class = getSymbol(value, environment, symbolName)
    if type(class) ~= "table" then
        return false
    end

    local marker = "__cpddDialogueControlRepair_" .. VERSION
    if class[marker] then
        return true
    end

    local wrapped = 0
    for _, methodName in ipairs(methodNames) do
        local original = class[methodName]
        if type(original) == "function" then
            class[methodName] = function(self, ...)
                local results = { original(self, ...) }
                if runtimeUIRepairEnabled() then
                    repair(self)
                    scheduleRepairBurst(self, repair, 0.10)
                end
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    class[marker] = true
    if wrapped > 0 then
        report("installed exact English dialogue controls for " .. source)
    end
    return wrapped > 0
end

local function installExactWidgetRepair(value, environment, symbolName, methodNames, repair, source, repeatRepair)
    local class = getSymbol(value, environment, symbolName)
    if type(class) ~= "table" then
        return false
    end

    local marker = "__cpddExactWidgetRepair_" .. VERSION
    if class[marker] then
        return true
    end

    local wrapped = 0
    local repairedInstances = setmetatable({}, { __mode = "k" })
    for _, methodName in ipairs(methodNames) do
        local original = class[methodName]
        if type(original) == "function" then
            class[methodName] = function(self, ...)
                local results = { original(self, ...) }
                if runtimeUIRepairEnabled() and (repeatRepair or not repairedInstances[self]) then
                    if not repeatRepair then
                        repairedInstances[self] = true
                    end
                    repair(self)
                end
                return unpack(results)
            end
            wrapped = wrapped + 1
        end
    end

    class[marker] = true
    if wrapped > 0 then
        report("installed exact English widget labels for " .. source)
    end
    return wrapped > 0
end

-- The original creator widgets paint one Chinese character in each of two
-- large labels and keep the complete English word in a faint decorative
-- subtitle. The former PAK fix edited those two WidgetBlueprint assets. Do
-- the equivalent on the live widgets so bootstrap-only installs retain the
-- full choices without shipping cooked asset replacements.
local creatorChoiceLabels = {
    [1] = { "Madness", "Sanity" },
    [2] = { "Wisdom", "Power" },
    [3] = { "Glory", "Emotion" },
}

local function promoteCreatorChoiceLabel(container, firstName, secondName, promotedName, text)
    if container == nil then
        return false
    end

    local first = getNamedWidget(container, firstName)
    local second = getNamedWidget(container, secondName)
    local promoted = getNamedWidget(container, promotedName)
    if promoted == nil then
        return false
    end

    -- Remove the character-split labels and place the complete reviewed word
    -- in the existing full-width subtitle text block.
    runtimeFixes.setNamedWidgetText(container, firstName, "")
    runtimeFixes.setNamedWidgetText(container, secondName, "")
    runtimeFixes.setNamedWidgetText(container, promotedName, text)

    -- Reuse the normal label's exact cooked font and tint. This replaces the
    -- fictional-glyph subtitle font, its extreme tracking, and its low alpha
    -- without needing to construct a fragile FSlateFontInfo in Lua.
    local font = nil
    local color = nil
    pcall(function()
        if first ~= nil and first.GetFont ~= nil then
            font = first:GetFont()
        elseif first ~= nil then
            font = first.Font
        end
    end)
    pcall(function()
        if first ~= nil and first.GetColorAndOpacity ~= nil then
            color = first:GetColorAndOpacity()
        elseif first ~= nil then
            color = first.ColorAndOpacity
        end
    end)
    if font ~= nil then
        pcall(function() promoted.Font = font end)
        pcall(function()
            if promoted.SetFont ~= nil then promoted:SetFont(font) end
        end)
    end
    if color ~= nil then
        pcall(function() promoted.ColorAndOpacity = color end)
        pcall(function()
            if promoted.SetColorAndOpacity ~= nil then promoted:SetColorAndOpacity(color) end
        end)
    end

    pcall(function()
        if promoted.SetRenderOpacity ~= nil then promoted:SetRenderOpacity(1) end
    end)
    pcall(function()
        if promoted.SetLetterSpacing ~= nil then promoted:SetLetterSpacing(0) end
    end)
    pcall(function()
        if promoted.SetRenderTranslation ~= nil then
            promoted:SetRenderTranslation(FVector2D(-50, 0))
        end
    end)
    pcall(function()
        if promoted.Slot ~= nil and promoted.Slot.SetPadding ~= nil then
            promoted.Slot:SetPadding(FMargin(0, 0, 0, 0))
        end
    end)
    pcall(function()
        if promoted.SynchronizeProperties ~= nil then promoted:SynchronizeProperties() end
    end)
    pcall(function()
        if promoted.InvalidateLayoutAndVolatility ~= nil then
            promoted:InvalidateLayoutAndVolatility()
        end
    end)
    return true
end

local function repairCreateRoleChoiceLabels(self)
    local labels = creatorChoiceLabels[tonumber(self and self.nowIndex)]
    local view = self and self.view
    if labels == nil or view == nil then
        return false
    end

    local left = getNamedWidget(view, "WBP_CreateRole_Answer_Sub01")
    local right = getNamedWidget(view, "WBP_CreateRole_Answer_Sub02")
    local changed = promoteCreatorChoiceLabel(
        left,
        "Text_Answer_Text01_L",
        "Text_Answer_Text02_L",
        "Text_Answer_TheLeon01_L",
        labels[1]
    )
    changed = promoteCreatorChoiceLabel(
        right,
        "Text_Answer_Text01_R",
        "Text_Answer_Text02_R",
        "Text_Answer_TheLeon01_R",
        labels[2]
    ) or changed
    return changed
end

local function compactOverallGraphicsChoices(self)
    if self == nil or type(self.ChoiceListData) ~= "table" then
        return false
    end
    local overallConst = nil
    pcall(function()
        overallConst = Enum.ESettingConstData.OVERALL_SCALABILITY_LEVEL
    end)
    if overallConst == nil or self.MetaData == nil or self.MetaData.Const_1 ~= overallConst then
        return false
    end

    self.bTextLengthExceed = false
    for _, choice in pairs(self.ChoiceListData) do
        if type(choice) == "table" then
            choice.bTextLengthExceed = false
        end
    end

    local list = self.Hori_ChoiceCom
    if list ~= nil and type(list.Refresh) == "function" then
        pcall(list.Refresh, list, self.ChoiceListData)
        if type(self.UpdateData) == "function" then
            pcall(self.UpdateData, self, false)
        end
        return true
    end
    return false
end

local function installSettingsPresetLayoutRepair(value, environment)
    local class = getSymbol(value, environment, "Settings_Option_Item")
    if type(class) ~= "table" or class.__cpddCompactGraphicsPresets == VERSION then
        return false
    end
    local originalRefresh = class.Refresh
    if type(originalRefresh) ~= "function" then
        return false
    end

    class.Refresh = function(self, ...)
        local results = { originalRefresh(self, ...) }
        compactOverallGraphicsChoices(self)
        return unpack(results)
    end
    class.__cpddCompactGraphicsPresets = VERSION
    report("installed compact overall graphics preset row")
    return true
end

local viewRepairSpecs = {
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.SkillCommon_Panel",
        "SkillCommon_Panel",
        { "OnRefresh", "RefreshBeStrongArea" },
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.Skill_BeStrong_Btn",
        "Skill_BeStrong_Btn",
        { "Refresh", "UpdateState" },
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.Secret.Skill_Secret_Detail",
        "Skill_Secret_Detail",
        { "Refresh", "RefreshSkillInfo", "IShowSkillDesc" },
    },
    {
        "Gameplay.LogicSystem.Guild.GuildInside.Members.GuildInside_Permission_Panel.GuildInside_Permission_Panel",
        "GuildInside_Permission_Panel",
        { "OnRefresh", "OnReceiveGuildRights", "RefreshRightsData" },
    },
    {
        "Gameplay.LogicSystem.Task.New.Task_Main_Panel",
        "Task_Main_Panel",
        { "OnRefresh", "refreshTabList" },
    },
}

local exactWidgetRepairSpecs = {
    {
        "Gameplay.LogicSystem.CreateRole.CreateRoleAnswer_Panel",
        "CreateRoleAnswer_Panel",
        { "setChooseInfo" },
        repairCreateRoleChoiceLabels,
        true,
    },
    {
        "Gameplay.LogicSystem.NPC.NPCBtnCut",
        "NPCBtnCut",
        { "InitUIView", "Refresh" },
        runtimeFixes.repairScreenshotLabel,
        true,
    },
    {
        "Gameplay.LogicSystem.LoginPopUp.LoginActivityPopUp_Panel",
        "LoginActivityPopUp_Panel",
        { "InitUIView", "OnRefresh", "on_KGListViewCom_ItemSelected", "ShowTitle" },
        runtimeFixes.repairLoginActivityLabels,
    },
    {
        "Gameplay.LogicSystem.Item.NewUI.ItemTagCenter",
        "ItemTagCenter",
        { "SetData" },
        runtimeFixes.repairItemReceivedLabels,
    },
    {
        "Gameplay.LogicSystem.SecretPartner.Gacha.SecretPartner_Gacha_Get_Panel",
        "SecretPartner_Gacha_Get_Panel",
        {
            "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh",
            "RefreshView", "UpdateUI", "PlayAnimation",
        },
        runtimeFixes.repairDynamicPanelLabels,
        true,
    },
    {
        "Gameplay.LogicSystem.SecretPartner.Star.SecretPartner_StarUp_Panel",
        "SecretPartner_StarUp_Panel",
        {
            "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh",
            "RefreshView", "UpdateUI", "PlayAnimation",
        },
        runtimeFixes.repairDynamicPanelLabels,
        true,
    },
    {
        "Gameplay.LogicSystem.DiceRollV2.Panels.DiceRollV2_Result_Succ_Panel",
        "DiceRollV2_Result_Succ_Panel",
        { "InitUIView", "OnRefresh", "PlaySuccessAnim" },
        runtimeFixes.repairDiceResultLabels,
    },
    {
        "Gameplay.LogicSystem.DiceRollV2.Panels.DiceRollV2_Result_SuccessDefault",
        "DiceRollV2_Result_SuccessDefault",
        { "InitUIView", "Refresh" },
        runtimeFixes.repairDiceResultLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.SkillUpgradeTips_Panel",
        "SkillUpgradeTips_Panel",
        { "InitUIView", "OnRefresh", "SetContent" },
        runtimeFixes.repairSkillUpgradeTipsLabels,
    },
    {
        "Gameplay.LogicSystem.SecretPartner.SecretPartner_Panel",
        "SecretPartner_Panel",
        {
            "InitUIView", "OnRefresh", "OnShow", "RefreshMainTab",
            "on_WBP_SecretPuppetTabListCom_ItemSelected",
        },
        runtimeFixes.repairSecretPartnerLabels,
    },
    {
        "Gameplay.LogicSystem.SecretPartner.Base.SecretPartnerBase_Sub",
        "SecretPartnerBase_Sub",
        {
            "InitUIView", "Refresh", "RefreshPartnerItemListPanel",
            "RefreshPartnerItemList", "RefreshSecretPartnerSelectedState",
        },
        runtimeFixes.repairSecretPartnerLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.Skill_BeStrong_Btn",
        "Skill_BeStrong_Btn",
        { "InitUIView", "Refresh", "UpdateState" },
        runtimeFixes.repairSkillHeaderLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.Main.SkillCommon_Panel",
        "SkillCommon_Panel",
        { "InitUIView", "OnRefresh", "InitSkillCustomizer", "RefreshBeStrongArea" },
        runtimeFixes.repairSkillCommonLabels,
    },
    {
        "Gameplay.LogicSystem.Talent.Talent_Panel",
        "Talent_Panel",
        {
            "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh",
            "RefreshView", "refreshOneClickStatus", "refreshEnableStatus",
        },
        runtimeFixes.repairTalentLabels,
    },
    {
        "Gameplay.LogicSystem.Equipment.Reform.EquipmentForging_Plan_Panel",
        "EquipmentForging_Plan_Panel",
        { "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh", "RefreshView", "UpdateUI" },
        runtimeFixes.repairEmbeddedSkillHeaderLabels,
    },
    {
        "Gameplay.LogicSystem.PlayerDetails.ExtraordinaryScore.ExtraordinaryScore_Panel",
        "ExtraordinaryScore_Panel",
        { "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh", "RefreshView", "UpdateUI" },
        runtimeFixes.repairEmbeddedSkillHeaderLabels,
    },
    {
        "Gameplay.LogicSystem.PlayerDetails.PlayerTotal_Panel",
        "PlayerTotal_Panel",
        { "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh", "RefreshView", "UpdateUI" },
        runtimeFixes.repairEmbeddedSkillHeaderLabels,
    },
    {
        "Gameplay.LogicSystem.Sealed_2.Sealed_Main_Panel",
        "Sealed_Main_Panel",
        { "InitUIView", "OnRefresh", "OnOpen", "OnShow", "Refresh", "RefreshView", "UpdateUI" },
        runtimeFixes.repairEmbeddedSkillHeaderLabels,
    },
    {
        "Gameplay.LogicSystem.Equipment.Equipment_Panel",
        "Equipment_Panel",
        { "InitUIView", "OnRefresh", "RefreshCurrentTabPage" },
        runtimeFixes.repairEquipmentLabels,
    },
    {
        "Gameplay.LogicSystem.Equipment.Reform.EquipmentReform_Page",
        "EquipmentReform_Page",
        { "RefreshReformPanelState" },
        runtimeFixes.repairEquipmentReformUnlockText,
        true,
    },
    {
        "Gameplay.LogicSystem.Bag.MainBag.Bag_Panel",
        "Bag_Panel",
        { "InitUIView", "OnRefresh", "UpdateAutoDecomposeBtn", "UpdateAutoDecomposeOpenSwitch" },
        runtimeFixes.repairBagLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.SchemePlan.Scheme_Plan_Item",
        "Scheme_Plan_Item",
        { "InitUIView", "OnRefresh" },
        runtimeFixes.repairSchemePlanItemLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.OneClick.OneClick_Plan_Item",
        "OneClick_Plan_Item",
        { "InitUIView", "OnRefresh", "SetAsDefault", "UpdateEquip" },
        runtimeFixes.repairSchemePlanItemLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.OneClick.OneClick_PlanType_Tab_Item",
        "OneClick_PlanType_Tab_Item",
        { "InitUIView", "OnRefresh", "Refresh", "UpdateEquip", "UpdateUse" },
        runtimeFixes.repairSchemeUseLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.SchemeAssembly.Scheme_CustomPlan_Item",
        "Scheme_CustomPlan_Item",
        { "InitUIView", "OnRefresh", "SetAsAddPlan", "UpdateSelectionState" },
        runtimeFixes.repairSchemeUseLabels,
    },
    {
        "Gameplay.LogicSystem.SkillCustomizer.SchemeAssembly.Scheme_CustomPlan_Equipment_Item",
        "Scheme_CustomPlan_Equipment_Item",
        { "InitUIView", "OnRefresh", "SetAsAddPlan", "UpdateSelectionState" },
        runtimeFixes.repairSchemeUseLabels,
    },
    {
        "Gameplay.LogicSystem.Equipment.Wear.Equipment_Wear_Attribute_Item",
        "Equipment_Wear_Attribute_Item",
        { "InitUIView", "OnRefresh", "Refresh", "UpdateUse", "SetUse" },
        runtimeFixes.repairSchemeUseLabels,
    },
    {
        "Gameplay.LogicSystem.Equipment.Wear.Equipment_Wear_Suit_Item",
        "Equipment_Wear_Suit_Item",
        { "InitUIView", "OnRefresh", "Refresh", "UpdateUse", "SetUse" },
        runtimeFixes.repairSchemeUseLabels,
    },
    {
        "Gameplay.LogicSystem.HUD.HUD_PVPLastHunt.PVPLastHunt_Details_MyData",
        "PVPLastHunt_Details_MyData",
        { "InitUIView", "OnRefresh", "RefreshBasicInfo", "RefreshRewardInfo" },
        runtimeFixes.repairLastHuntMyDataLabels,
    },
}

local dataRepairSpecs = {
    {
        "Framework.KGFramework.KGUI.Component.Tools.UIComDiyTitle",
        "UIComDiyTitle",
        { "Refresh" },
    },
    {
        "Gameplay.LogicSystem.Gossip.GossipSystem",
        "GossipSystem",
        { "PlayBubbleByEidOrUid", "PlayBottomBubble" },
    },
    {
        "Gameplay.LogicSystem.NewHeadInfo.HeadInfoUI.HeadInfoBubble",
        "HeadInfoBubble",
        { "ShowCustomBubble" },
    },
    {
        "Gameplay.LogicSystem.HUD.HUD_Aside.HUDAside_Bubble",
        "HUDAside_Bubble",
        { "Refresh" },
    },
    {
        "Gameplay.LogicSystem.NPC.Sequence.Sequence_Panel",
        "Sequence_Panel",
        { "ShowDialoguePanel", "OnSetBottomText" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Button.UIComText",
        "UIComText",
        { "Refresh" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Button.UIComButton",
        "UIComButton",
        { "Refresh", "OnRefresh", "SetName" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Select.UIComDropDown",
        "UIComDropDown",
        { "Refresh", "refreshOptionsList", "refreshOptionBtn" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Select.UIComDropDownItem",
        "UIComDropDownItem",
        { "OnRefresh", "SetName" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Tab.UIComTabList",
        "UIComTabList",
        { "Refresh" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Tab.UIComSimpleTabList",
        "UIComSimpleTabList",
        { "Refresh" },
    },
    {
        "Framework.KGFramework.KGUI.Component.Tab.UIComTabItem",
        "UIComTabItem",
        { "OnRefresh" },
    },
    {
        "Gameplay.LogicSystem.Lib.LibText",
        "LibText",
        { "Refresh" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsText_Item",
        "ItemTipsText_Item",
        { "OnRefresh" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipStory",
        "ItemTipsEquipStory",
        { "SetData" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipSuit",
        "ItemTipsEquipSuit",
        { "SetData" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipSuitItem",
        "ItemTipsEquipSuitItem",
        { "OnRefresh" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipSpirituality",
        "ItemTipsEquipSpirituality",
        { "SetData" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsQuickAssembly_Page",
        "ItemTipsQuickAssembly_Page",
        { "SetContent" },
    },
    {
        "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsQuickAssembly_Entry_Page",
        "ItemTipsQuickAssembly_Entry_Page",
        { "SetContent" },
    },
}

local function registerViewRepair(spec)
    local moduleName, symbolName, methodNames = spec[1], spec[2], spec[3]
    Loader.AfterLoad(moduleName, function(value, environment)
        installViewMethodRepair(value, environment, symbolName, methodNames, moduleName)
        return value
    end, 1000000, "cpdd.runtime-fix.view." .. moduleName:gsub("[^%w]", "-"))
end

local function registerDataRepair(spec)
    local moduleName, symbolName, methodNames = spec[1], spec[2], spec[3]
    Loader.AfterLoad(moduleName, function(value, environment)
        installDataMethodRepair(value, environment, symbolName, methodNames, moduleName)
        return value
    end, 1000000, "cpdd.runtime-fix.data." .. moduleName:gsub("[^%w]", "-"))
end


local function registerExactWidgetRepair(spec)
    local moduleName, symbolName, methodNames, repair, repeatRepair = spec[1], spec[2], spec[3], spec[4], spec[5]
    Loader.AfterLoad(moduleName, function(value, environment)
        installExactWidgetRepair(value, environment, symbolName, methodNames, repair, moduleName, repeatRepair)
        return value
    end, 1000000, "cpdd.runtime-fix.exact-widget." .. moduleName:gsub("[^%w]", "-"))
end

for _, spec in ipairs(viewRepairSpecs) do
    registerViewRepair(spec)
end
for _, spec in ipairs(dataRepairSpecs) do
    registerDataRepair(spec)
end
for _, spec in ipairs(exactWidgetRepairSpecs) do
    registerExactWidgetRepair(spec)
end

Loader.AfterLoad(
    "Gameplay.LogicSystem.Item.Popup.ItemTips.ItemTipsEquipSpecial",
    function(value, environment)
        runtimeMetrics.InstallEquipmentSpecialTextRepair(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.item-tips-equip-special"
)

Loader.AfterLoad(
    "Gameplay.LogicSystem.Sealed_2.SealedSystem",
    function(value, environment)
        runtimeMetrics.InstallSealedSkillDescRepair(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.sealed-skill-description"
)

Loader.AfterLoad("Gameplay.LogicSystem.Guild.GuildSystem", function(value, environment)
    installGuildRoleRepair(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.guild-role-names")

Loader.AfterLoad("Gameplay.LogicSystem.Settings.Settings_Option_Item", function(value, environment)
    installSettingsPresetLayoutRepair(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.compact-graphics-presets")

Loader.AfterLoad("Gameplay.LogicSystem.HUD.HUD_PVPLastHunt.PVPLastHunt_Details_MyData", function(value, environment)
    runtimeFixes.installLastHuntScoreFormatting(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.last-hunt-score-format")

Loader.AfterLoad("Gameplay.LogicSystem.Utils.CurrencyUtils", function(value, environment)
    runtimeFixes.installCurrencyFormatting(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.currency-number-format")

Loader.AfterLoad(
    "Gameplay.LogicSystem.DungeonBattleStatistics.DungeonBattleStatisticsSystem",
    function(value, environment)
        runtimeFixes.installBattleStatisticsFormatting(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.dps-number-format"
)

Loader.AfterLoad("Gameplay.LogicSystem.PVP.Stats.PVP_Stats_Item", function(value, environment)
    runtimeMetrics.InstallPvpStatisticsFormatting(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.pvp-scoreboard-number-format")

Loader.AfterLoad("Gameplay.LogicSystem.NPC.Dialogue.DialogueTalk", function(value, environment)
    installDialogueTalkRepair(value, environment)
    return value
end, 1000000, "cpdd.runtime-fix.dialogue-layout")

Loader.AfterLoad("Gameplay.LogicSystem.NPC.Dialogue.Dialogue_Panel", function(value, environment)
    installDialogueControlRepair(
        value,
        environment,
        "Dialogue_Panel",
        {
            "InitUIView", "OnRefresh", "OnOpen", "RefreshPCModeKeyPrompt",
            "SetReviewButtonVisible", "SetSkipButtonVisible",
        },
        repairDialoguePanelLabels,
        "Dialogue_Panel"
    )
    return value
end, 1000000, "cpdd.runtime-fix.dialogue-panel-controls")

Loader.AfterLoad("Gameplay.LogicSystem.NPC.Dialogue.Dialogue_NPCBtnSkip", function(value, environment)
    installDialogueControlRepair(
        value,
        environment,
        "Dialogue_NPCBtnSkip",
        { "InitUIView", "Refresh" },
        repairDialogueSkipLabels,
        "Dialogue_NPCBtnSkip"
    )
    return value
end, 1000000, "cpdd.runtime-fix.dialogue-skip-controls")

local function installShortMenuLabels(value, environment)
    local class = getSymbol(value, environment, "MenuBtn_Item")
    if type(class) ~= "table" or type(class.OnRefresh) ~= "function" then
        return false
    end
    if class.__cpddShortMenuLabels then
        return true
    end

    local originalRefresh = class.OnRefresh
    class.OnRefresh = function(self, params)
        local results = { originalRefresh(self, params) }
        local menuId = self.MenuID
        local menuData = menuId and Game and Game.TableData and Game.TableData.GetMenuDataRow(menuId)
        local label = menuData and shortMenuLabels[menuData.ButtonEnum]
        if label and self.view then
            -- KGTextBlock can repaint its serialized long translation after
            -- OnRefresh. Persist the compact value in both the widget property
            -- and the live Slate text so later menu refreshes cannot restore it.
            runtimeFixes.setNamedWidgetText(self.view, "Text_Name", label)
        end
        return unpack(results)
    end
    class.__cpddShortMenuLabels = true
    report("installed compact English menu labels")
    return true
end

Loader.AfterLoad(
    "Gameplay.LogicSystem.Menu.MenuBtn_Item",
    function(value, environment)
        installShortMenuLabels(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.short-menu-labels"
)

-- Item tooltips are reused for subsequent hovered items without closing their
-- UIComponent. Rescan only this proven dynamic panel on Refresh; the pending
-- delayed pass coalesces bursts so this does not restore the global sweep.
local dynamicPanelRescanUids = {
    ActivityMain_Panel = true,
    BagItemTips_Panel = true,
    FashionStation_Details_Panel = true,
    NewbieGuide_MainPanel = true,
    Sequence_Panel = true,
    TrainTrade_Hud_Panel = true,
}

local extendedPanelRepairDelays = {
    FashionStation_Details_Panel = { 0.25, 0.75, 1.50 },
    NewbieGuide_MainPanel = { 0.25, 0.75, 1.50, 3.00 },
    Sequence_Panel = { 0.50, 1.50, 3.00, 6.00, 10.00, 20.00 },
}

local function isDynamicPanelRescan(component)
    if component == nil then
        return false
    end
    local uid = component.uid or component.UID or component.__cname
    return uid ~= nil and dynamicPanelRescanUids[tostring(uid)] == true
end

local panelTextRepair = {
    States = setmetatable({}, { __mode = "k" }),
    Reports = {},
}

function panelTextRepair:StateKey(component)
    if component == nil then return nil end
    return component.userWidget or component.widget or component
end

function panelTextRepair:Repair(component, reason)
    if not runtimeUIRepairEnabled() or component == nil or component.isDestroyed then
        return 0
    end
    local started = nowMilliseconds()
    local repaired = 0
    local visitedComponents = {}
    local function repairComponent(current)
        if current == nil or current.isDestroyed or visitedComponents[current] then return end
        visitedComponents[current] = true
        local rootWidget = current.userWidget or current.widget
        local discoveryContext = nil
                repaired = repaired + (translateViewTextWidgets(
            current.view,
            rootWidget,
            discoveryContext,
            current
        ) or 0)

        -- Child UIComponents and cached subviews own independent UWidgetTrees.
        -- Walking them is the important coverage difference from the old panel
        -- pass, and remains bounded to the panel being opened or refreshed.
        if type(current._childComponents) == "table" then
            for _, child in pairs(current._childComponents) do repairComponent(child) end
        end
    end
    repairComponent(component)
        runtimeMetrics.PanelsRepaired = runtimeMetrics.PanelsRepaired + 1
    runtimeMetrics.PanelRepairMillis = runtimeMetrics.PanelRepairMillis + (nowMilliseconds() - started)
    runtimeMetrics.PanelLabelsRepaired = runtimeMetrics.PanelLabelsRepaired + repaired
    if repaired > 0 then
        local label = tostring(component.uid or component.__cname or reason or "panel")
        local summary = self.Reports[label]
        if summary == nil then
            self.Reports[label] = { Events = 1, Labels = repaired }
            report("event-driven panel repair active for " .. label
                .. "; later instances are aggregated")
        else
            summary.Events = summary.Events + 1
            summary.Labels = summary.Labels + repaired
            runtimeMetrics.PanelRepairReportsSuppressed =
                runtimeMetrics.PanelRepairReportsSuppressed + 1
        end
    end
    return repaired
end

function panelTextRepair:ProcessOnce(component, reason)
    if component == nil then return 0 end
    local repeatable = isDynamicPanelRescan(component)
    local key = self:StateKey(component)
    local state = self.States[key]
    if state == nil then
        state = {}
        self.States[key] = state
    end
    local alreadyScanned = state.Scanned == true
    if alreadyScanned and not repeatable then
        return 0
    end
    state.Scanned = true
    if alreadyScanned then
        self:Queue(component, true)
        return 0
    end
    local repaired = self:Repair(component, reason)
    self:Queue(component, repeatable)
    self:QueueExtended(component)
    return repaired
end

function panelTextRepair:Queue(component, repeatable)
    local key = self:StateKey(component)
    local state = self.States[key]
    if state == nil then
        state = {}
        self.States[key] = state
    elseif state.Pending or (state.DelayedDone and not repeatable) then
        return
    end
    state.Pending = true
    local scheduled = scheduleRepairAfter(component, 0.10, function(liveComponent)
        local liveState = self.States[self:StateKey(liveComponent)]
        if liveState then
            liveState.Pending = false
            if not repeatable then
                liveState.DelayedDone = true
            end
        end
        self:Repair(liveComponent, "delayed")
    end)
    if not scheduled then
        state.Pending = false
    end
end

function panelTextRepair:QueueExtended(component)
    local uid = component and (component.uid or component.UID or component.__cname)
    local delays = uid and extendedPanelRepairDelays[tostring(uid)] or nil
    if delays == nil then
        return
    end
    local key = self:StateKey(component)
    local state = self.States[key]
    if state == nil then
        state = {}
        self.States[key] = state
    elseif state.ExtendedQueued then
        return
    end
    state.ExtendedQueued = true
    for _, delay in ipairs(delays) do
        scheduleRepairAfter(component, delay, function(liveComponent)
            self:Repair(liveComponent, "extended-" .. tostring(delay))
        end)
    end
end

local function installEventDrivenPanelRepair(value, environment)
    local class = getSymbol(value, environment, "UIComponent")
    if type(class) ~= "table" or rawget(class, "__cpddEventTextRepair") == VERSION then
        return false
    end

    for _, methodName in ipairs({ "Open", "Refresh" }) do
        local original = rawget(class, methodName)
        if type(original) == "function" then
            class[methodName] = function(self, ...)
                local results = { original(self, ...) }
                panelTextRepair:ProcessOnce(self, methodName)
                return unpack(results)
            end
        end
    end
    local originalClose = rawget(class, "Close")
    if type(originalClose) == "function" then
        class.Close = function(self, ...)
            panelTextRepair.States[panelTextRepair:StateKey(self)] = nil
            invalidateWidgetCache(self and (self.userWidget or self.widget))
            return originalClose(self, ...)
        end
    end
    class.__cpddEventTextRepair = VERSION
    report("installed event-driven panel text repair")
    return true
end

Loader.AfterLoad(
    "Framework.KGFramework.KGUI.Core.UIComponent",
    function(value, environment)
        installEventDrivenPanelRepair(value, environment)
        return value
    end,
    1000000,
    "cpdd.runtime-fix.event-driven-panels"
)

local function statisticsEverywhereEnabled()
    local loader = rawget(_G, "LOMModLoader")
    local features = loader and loader.Features
    if type(features) ~= "table" then
        return true
    end
    return features.StatisticsEverywhere ~= false
end

local function installStatisticsEverywhereTarget(target, label)
    if type(target) ~= "table" then
        return false
    end
    if rawget(target, "__cpddStatisticsEverywhereVersion") == VERSION then
        return true
    end

    local original = rawget(target, "CheckSwitchMapStats")
    if type(original) ~= "function" then
        return false
    end

    target.CheckSwitchMapStats = function(...)
        if statisticsEverywhereEnabled() then
            return true
        end
        return original(...)
    end
    target.__cpddStatisticsEverywhereVersion = VERSION
    report("installed Statistics button everywhere hook for " .. tostring(label))
    return true
end

local function installStatisticsEverywhere(value, environment)
    local installed = false
    if type(value) == "table" then
        installed = installStatisticsEverywhereTarget(value, "module") or installed
        installed = installStatisticsEverywhereTarget(rawget(value, "HUDMiddleMenuCheck"), "module.HUDMiddleMenuCheck") or installed
    end
    if type(environment) == "table" and environment ~= value then
        installed = installStatisticsEverywhereTarget(environment, "environment") or installed
        installed = installStatisticsEverywhereTarget(rawget(environment, "HUDMiddleMenuCheck"), "environment.HUDMiddleMenuCheck") or installed
    end
    return value
end

local function setStatisticsEverywhere(enabled)
    local loader = rawget(_G, "LOMModLoader")
    if loader == nil then
        loader = { Features = {} }
        rawset(_G, "LOMModLoader", loader)
    elseif type(loader.Features) ~= "table" then
        loader.Features = {}
    end
    loader.Features.StatisticsEverywhere = enabled == true

    pcall(function()
        if Game and Game.HUDMiddleMenuSystem and Enum and Enum.EHUD_MiddleMenu then
            Game.HUDMiddleMenuSystem:UpdateMiddleMenuBtn(Enum.EHUD_MiddleMenu.SwitchMapStats)
        end
    end)
    return loader.Features.StatisticsEverywhere
end

Loader.AfterLoad(
    "Gameplay.LogicSystem.HUD.HUD_MiddleBtnContent.HUDMiddleMenuCheck",
    installStatisticsEverywhere,
    1000000,
    "cpdd.runtime-fix.statistics-everywhere"
)

Loader.On("after_main", function()
    -- Hooks apply immediately to already-loaded modules and through the loader
    -- for future modules. Reapply only the loaded set; never force-load UI/data
    -- modules during the launch-critical after_main phase.
    if type(Loader.ReapplyAll) == "function" then
        Loader.ReapplyAll()
    end
    report("startup metrics gemini_loads=" .. tostring(runtimeMetrics.GeminiLoads)
        .. " source_shards=" .. tostring(runtimeMetrics.SourceShardLoads)
        .. " widget_indexes=" .. tostring(runtimeMetrics.WidgetIndexesBuilt)
        .. " get_all_widgets=" .. tostring(runtimeMetrics.GetAllWidgetsCalls)
        .. " cache_hits=" .. tostring(runtimeMetrics.TranslationCacheHits + runtimeMetrics.LiveRepairCacheHits)
        .. " cache_misses=" .. tostring(runtimeMetrics.TranslationCacheMisses + runtimeMetrics.LiveRepairCacheMisses))
    end, 1500, "cpdd.runtime-fix.translation-layout")

report("registered v" .. VERSION)
return {
    Version = VERSION,
    PerformanceModeApplied = Loader.Telemetry.PerformanceModeApplied == true,
    RepairLiveText = repairLiveString,
    SetRuntimeRowRepair = setRuntimeRowRepair,
    IsRuntimeRowRepairEnabled = runtimeRowRepairEnabled,
    SetRuntimeUIRepair = setRuntimeUIRepair,
    IsRuntimeUIRepairEnabled = runtimeUIRepairEnabled,
    SetStatisticsEverywhere = setStatisticsEverywhere,
    IsStatisticsEverywhereEnabled = statisticsEverywhereEnabled,
    PerformanceMetrics = runtimeMetrics,
    RepairPanel = function(component) return panelTextRepair:Repair(component, "manual") end,
        }
