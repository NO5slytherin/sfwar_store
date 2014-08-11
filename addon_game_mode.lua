TIME_HERO_SELECTION , TIME_PRE_GAME , TIME_POST_GAME , = 10.0 , 10.0 , 10.0

TIME_ROUND_REST = 10.0
TOTAL_ROUNDS = 11

GOLD_TICK_TIME = 60.0
GOLD_PER_TICK = 0


CUSTOM_STATE_PREPARE = 0
CUSTOM_STATE_IN_ROUND = 1
CUSTOM_STATE_ROUND_REST = 2
CUSTOM_STATE_GAME_END = 3

if SFWarsMode == nil then
	SFWarsMode = class({})
end

function Activate()
	SFWarsMode:InitGameMode()
end

function SFWarsMode:InitGameMode()
	self.eGameEntity = GameRules:GetGameModeEntity()

	self:InitPara()
	self:SetGameRules()
	self:RegisterEventListener()
	self:StartThink()
end

function SFWarsMode:InitPara()
	self.nCurrState = CUSTOM_STATE_PREPARE
	self.RoundCount = 0
	self.nGoodWinRounds = 0
	self.nBadWinRounds  = 0
end

function SFWarsMode:SetGameRules()
	GameRules:SetTimeOfDay( 0.75 )
	GameRules:SetHeroRespawnEnabled( false )
	GameRules:SetUseUniversalShopMode( false )
	GameRules:SetHeroSelectionTime( TIME_HERO_SELECTION )
	GameRules:SetPreGameTime( TIME_PRE_GAME )
	GameRules:SetPostGameTime( TIME_POST_GAME )
	GameRules:SetTreeRegrowTime( 60.0 )
	--GameRules:SetHeroMinimapIconSize( 400 )
	--GameRules:SetCreepMinimapIconScale( 0.7 )
	--GameRules:SetRuneMinimapIconScale( 0.7 )
	GameRules:SetGoldTickTime( GOLD_TICK_TIME )
	GameRules:SetGoldPerTick( GOLD_PER_TICK )
	--GameRules:GetGameModeEntity():SetRemoveIllusionsOnDeath( true )
	GameRules:GetGameModeEntity():SetTopBarTeamValuesOverride( true )
	--GameRules:GetGameModeEntity():SetTopBarTeamValuesVisible( false )
end

function SFWarsMode:RegisterEventListener()
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( SFWarsMode, "OnEntityKilled" ), self )
	ListenToGameEvent( "player_connect_full", Dynamic_Wrap( SFWarsMode, "OnPlayerConnectFull" ), self )
end

function SFWarsMode:StartThink()
	local gameEntity = GameRules:GetGameModeEntity()
	gameEntity:SetThink('OnThink' , self , 1 )
end

function SFWarsMode:OnThink()
	if self.t0 == nil then
		self.t0 = GameRules:GetGameTime()
	end
	local time = GameRules:GetGameTime()
	local dt = time - self.t0

	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then

		if self.nCurrState == CUSTOM_STATE_PREPARE then
			self:ThinkPrePare(dt)		
		elseif self.nCurrState == CUSTOM_STATE_IN_ROUND then
			self:ThinkInRound(dt)	
		elseif self.nCurrState == CUSTOM_STATE_ROUND_REST then
			self:ThinkRoundRest(dt)
		elseif self.nCurrState == CUSTOM_STATE_GAME_END then
			self:ThinkGameEnd()
		end
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then		-- Safe guard catching any state that may exist beyond DOTA_GAMERULES_STATE_POST_GAME
		return nil
	end
	return 1
end

function SFWarsMode:ThinkPrePare(dt)
	if GameRules:State_Get() > DOTA_GAMERULES_STATE_PRE_GAME then
		
		self.nCurrState = CUSTOM_STATE_ROUND_REST
		
		local center_msg = {
			message = '#sfwars_game_start_in_10',
			duration = 5
		}
		FireGameEvent('show_center_message',center_message)
	end
end

function SFWars:ThinkRoundRest(dt)
	if self.fTimeRested == nil then
		self.fTimeRested = 0
	end
	self.fTimeRested = self.fTimeRested + dt
	if self.fTimeRested >= TIME_ROUND_REST then
		self.RoundCount = self.RoundCount + 1
		self.nCurrState = CUSTOM_STATE_IN_ROUND
	else
		local fTimeLeft = TIME_ROUND_REST - self.fTimeRested
		if fTimeLeft < 1 then
			self:ShowCenterMessage('1',0.9)
			do return end
		elseif fTimeLeft < 2 then
			self:ShowCenterMessage('2',0.9)
			do return end
		elseif fTimeLeft < 3 then
			self:ShowCenterMessage('3',0.9)
			do return end
		end
	end
end

function SFWars:ThinkInRound(dt)
	local nGoodAlive = 0
	local nBadAlive = 0
	for i = 0,9 do
		local hPlayer = PlayerResource:GetPlayer(i)
		local hHero = hPlayer:GetAssignedHero()
		if hHero then
			if hHero:IsAlive then
				if hPlayer:GEtTeam() == DOTA_TEAM_GOODGUYS then
					nGoodAlive = nGoodAlive + 1
				elseif hPlayer:GEtTeam() == DOTA_TEAM_BADGUYS then
					nBadAlive = nBadAlive  + 1
				end
			end
		end
	end
	local bIsRoundEnd = self:IsRoundEnd(nGoodAlive,nBadAlive)
	if bIsRoundEnd then
		if self.RoundCount > TOTAL_ROUNDS then
			self.nCurrState = CUSTOM_STATE_GAME_END
		else
			self.nCurrState = CUSTOM_STATE_ROUND_REST
		end
	end
end

function SFWarsMode:IsRoundEnd(goodalive,badalive)
	if goodalive == 0 then
		self.nBadWinRounds = self.nBadWinRounds + 1
		GameRUles:SetTopBarTeamValue(DOTA_TEAM_GOODGUYS,self.nGoodWinRounds)
		GameRUles:SetTopBarTeamValue(DOTA_TEAM_BAD_GUYS,self.nBadWinRounds)
		return true
	end
	if badalive == 0 then
		self.nGoodWinRounds = self.nGoodWinRounds + 1
		GameRUles:SetTopBarTeamValue(DOTA_TEAM_GOODGUYS,self.nGoodWinRounds)
		GameRUles:SetTopBarTeamValue(DOTA_TEAM_BAD_GUYS,self.nBadWinRounds)
		return true
	end
	return false
end

function SFWarsMode:ThinkGameEnd()

	local WINNER == nil
	if self.nGoodWinRounds > self.nBadWinRounds then
		WINNER = DOTA_TEAM_GOODGUYS
	else
		WINNER = DOTA_TEAM_BADGUYS
	end

	GameRules:SetGameWinner(DOTA_TEAM_BADGUYS)

	GameRules:SetSafeToLeave(true)
end

function SFWarsMode:OnPlayerConnectFull(keys)
	local nIndex = keys.index + 1
	local hPlayer = EntIndexToHScript(nIndex)
	local nPlayerID = hPlayer:GetPlayerID()
	local hHero = hPlayer:GetAssignedHero()
	if hHero == nil then
		self.eGameEntity:SetContextThink('AutoAssignHero',
			function assign()
				CreateHeroForPlayer('npc_dota_hero_nevermore', hPlayer)
			end
			,0.1)
	end
	hHero = hPlayer:GetPlayerID()
	if hHero then
		self:SetAbilityPoints(hHero)
	end
end

function SFWarsMode:SetAbilityPoints(hero)
	for i = 1,hero:GetAbilityCount() do
		local ABILITY = hero:GetAbilityByIndex(i)
		if ABILITY then ABILITY:SetLevel(1) end
	end
	hero:SetAbilityPoints(0)
end


function SFWarsMode:ShowCenterMessage(msg,dt)
	if msg and dt then
		local center_message = {
			message = msg,
			duration = dt
		}
		FireGameEvent('show_center_message',center_message)
	end
end
