local Rand = math.Rand
local random = math.random
local ents_GetAll = ents.GetAll
local hook_Add = hook.Add
local HUD_PRINTTALK = HUD_PRINTTALK
local WorldSpaceCenter = WorldSpaceCenter


local attackOthers      = 			CreateLambdaConvar( "lambdaplayers_combat_attackothers", 0, true, false, false, "If Lambda Players should immediately start attacking anything at their sight.", 0, 1, { name = "Attack On Sight", type = "Bool", category = "Combat" } )
local huntDown          = 			CreateLambdaConvar( "lambdaplayers_combat_huntdownothers", 0, true, false, false, "If Lambda Players should hunt down other Lambdas. 'Attack On Sight' option needs to be enabled for it to work.", 0, 1, { name = "Search For Prey", type = "Bool", category = "Combat" } )
local defendMyself      = 			CreateLambdaConvar( "lambdaplayers_combat_defendmyself", 0, true, false, false, "If the Lambda Player being attacked should go after the attacker.", 0, 1, { name = "Defend Against Attacker", type = "Bool", category = "Combat" } )

if ( SERVER ) then

	local CurTime = CurTime
	local min = math.min

	local function LambdaOnInitialize( self )
		self.l_NextEnemySearchT = CurTime() + Rand( 0.33, 1.0 )
	end

	local function getEntityName(ent)
		if ent.IsLambdaPlayer then
			return ent:GetLambdaName()
		elseif ent:IsPlayer() then
			return ent:GetName()
		elseif ent:IsNPC() then
			return ent:GetClass()
		else
			return "Unknown Entity"
		end
	end

	local function LambdaOnThink( self, wepent, isdead )
		if isdead then return end

		if CurTime() > self.l_NextEnemySearchT then
			self.l_NextEnemySearchT = CurTime() + Rand( 0.33, 1.0 )

			if attackOthers:GetBool() and !self:InCombat() then
				
				local myPos = self:WorldSpaceCenter()
				local eneDist = ( self:InCombat() and myPos:DistToSqr( self:GetEnemy():WorldSpaceCenter() ) )
				local myForward = self:GetForward()
				local dotView = ( validEnemy and 0.33 or 0.5 )

				local surroundings = self:FindInSphere( nil, 2000, function( ent )

					if !LambdaIsValid( ent ) or self:IsPanicking() then return false end
					-- Avoid sleeping Lambdas from YerMash's Tranq Gun addon
					if ent.IsLambdaPlayer and ent:GetState( "Tranquilized" ) and ent.l_TranqGun_State == 3 then return false end

					local entPos = ent:WorldSpaceCenter()
					local los = ( entPos - myPos ); los.z = 0

					local selfName = getEntityName(self)
					local targetName = getEntityName(ent)

					los:Normalize()
					if los:Dot( myForward ) < dotView or eneDist and myPos:DistToSqr( entPos ) >= eneDist or !self:CanTarget( ent ) or !self:CanSee( ent ) then return false end
 
					--PrintMessage( HUD_PRINTTALK, selfName .. ": I'm attacking " .. targetName )

					-- I should defend myself. (Make their chance into a convar later)
					if defendMyself:GetBool() and random( 100 ) <= 65 and ent.IsLambdaPlayer then
						ent:AttackTarget( self )

						-- Our Victim should be scared!
						if random( 100 ) <= self:GetVoiceChance() then ent:PlaySoundFile( "panic" ) end

						--PrintMessage( HUD_PRINTTALK, targetName .. ": I'm defending myself against " .. selfName )
					end

					return ( self:IsInRange( ent, 1250 ) )
				end )

				if #surroundings > 0 then
					self:AttackTarget( surroundings[ random( #surroundings ) ] )
					-- Always play a taunt
					self:PlaySoundFile( "taunt" )
				end
			end
		end
	end

	local function LambdaOnBeginMove( self, pos, onNavmesh )
		local state = self:GetState()
		if state != "Idle" and state != "FindTarget" then return end
		
		if random( 1, 3 ) == 1 then

			local combatChance = ( self:GetCombatChance() * min( self:Health() / self:GetMaxHealth(), 1.0 ) )
			if random( 1, 100 ) <= combatChance then

				if huntDown:GetBool() and attackOthers:GetBool() then
					-- Let's find someone
					for _, ent in RandomPairs( ents_GetAll() ) do

						-- Let's not target sleeping Lambda's
						if ent.IsLambdaPlayer and ent:GetState( "Tranquilized" ) and ent.l_TranqGun_State == 3 then return end
						if ent != self and self:CanTarget( ent ) then

							local rndPos = ( self:GetRandomPosition( ent:GetPos(), random( 300, 550 ) ) )
							self:SetRun( random( 1, 3 ) == 1 )
							self:RecomputePath( rndPos )

							--if random( 100 ) <= self:GetVoiceChance() then self:PlaySoundFile( "witness" ) end
							self:PlaySoundFile( "witness" )

							--PrintMessage( HUD_PRINTTALK, self:GetLambdaName() .. ": I'm looking to hurt someone!" )
							return
						end
					end
				end
			end
		end
	end

	hook_Add( "LambdaOnInitialize", "LambdaOnInitialize", LambdaOnInitialize )
	hook_Add( "LambdaOnThink", "OnThink", LambdaOnThink )
	hook_Add( "LambdaOnBeginMove", "OnBeginMove", LambdaOnBeginMove )
end