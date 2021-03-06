--------------------------------------------------------------------------------
-- MicrobeEditor
--
-- Contains the functionality associated with creating and augmenting microbes
-- See http://www.redblobgames.com/grids/hexagons/ for mathematical basis of hex related code.
--------------------------------------------------------------------------------
class 'MicrobeEditor'

FLAGELIUM_MOMENTUM = 12.5

function MicrobeEditor:__init(hudSystem)
    self.currentMicrobe = nil
    self.organelleCount = 0
    self.activeActionName = nil
    self.hudSystem = hudSystem
    self.nextMicrobeEntity = nil
    self.lockedMap = nil
    self.placementFunctions = {["nucleus"] = MicrobeEditor.createNewMicrobe,
                               ["flagelium"] = MicrobeEditor.addMovementOrganelle,
                               ["mitochondria"] = MicrobeEditor.addProcessOrganelle,
                               ["toxin"] = MicrobeEditor.addAgentVacuole,
                               
                               ["vacuole"] = MicrobeEditor.addStorageOrganelle,
                             --  ["aminosynthesizer"] = MicrobeEditor.addProcessOrganelle,
                               ["remove"] = MicrobeEditor.removeOrganelle}
end

function MicrobeEditor:activate()
    playerEntity = Entity(Engine:playerData():activeCreature(), GameState.MICROBE)
    self.lockedMap = Engine:playerData():lockedMap()
    self.nextMicrobeEntity = playerEntity:transfer(GameState.MICROBE_EDITOR)
    self.nextMicrobeEntity:stealName("working_microbe")
    Engine:playerData():setBool("edited_microbe", true)
    Engine:playerData():setActiveCreature(self.nextMicrobeEntity.id)
end

function MicrobeEditor:update(milliseconds)
    if self.nextMicrobeEntity ~= nil then
        self.currentMicrobe = Microbe(self.nextMicrobeEntity)
        self.currentMicrobe.sceneNode.transform.orientation = Quaternion(Radian(Degree(180)), Vector3(0, 0, 1))-- Orientation
        self.currentMicrobe.sceneNode.transform.position = Vector3(0, 0, 0)
        self.currentMicrobe.sceneNode.transform:touch()
        self.nextMicrobeEntity = nil
    end
    for _, organelle in pairs(self.currentMicrobe.microbe.organelles) do
        if organelle.flashDuration ~= nil then
            organelle.flashDuration = nil
            organelle._colour = organelle._originalColour
            organelle._needsColourUpdate = true
        end
        if organelle._needsColourUpdate then
            organelle:_updateHexColours()
        end
    end
end

function MicrobeEditor:performLocationAction()
    if (self.activeActionName) then
        local func = self.placementFunctions[self.activeActionName]
        func(self, self.activeActionName)
    end
end

function MicrobeEditor:setActiveAction(actionName)
    self.activeActionName = actionName
end

function MicrobeEditor:getMouseHex()
    local mousePosition = Engine.mouse:normalizedPosition() 
    -- Get the position of the cursor in the plane that the microbes is floating in
    local rayPoint =  Entity(CAMERA_NAME .. "3"):getComponent(OgreCameraComponent.TYPE_ID):getCameraToViewportRay(mousePosition.x, mousePosition.y):getPoint(0)
    -- Convert to the hex the cursor is currently located over. 
    local q, r = cartesianToAxial(-rayPoint.x, rayPoint.y) -- Negating X to compensate for the fact that we are looking at the opposite side of the normal coordinate system
    local qr, rr = cubeToAxial(cubeHexRound(axialToCube(q, r))) -- This requires a conversion to hex cube coordinates and back for proper rounding.
    return qr, rr
end

function MicrobeEditor:removeOrganelle()
    local q, r = self:getMouseHex()
    if not (q == 0 and r == 0) then -- Don't remove nucleus
        local organelle = self.currentMicrobe:getOrganelleAt(q,r)
        if organelle then
            self.currentMicrobe:removeOrganelle(organelle.position.q ,organelle.position.r )
            self.currentMicrobe.sceneNode.transform:touch()
            self.organelleCount = self.organelleCount - 1
        end
    end
end


function MicrobeEditor:addStorageOrganelle(organelleType)
   -- self.currentMicrobe = Microbe(Entity("working_microbe", GameState.MICROBE))
    local q, r = self:getMouseHex()
    if self.currentMicrobe:getOrganelleAt(q, r) == nil then
        local storageOrganelle = StorageOrganelle(100.0)
        storageOrganelle:addHex(0, 0)
        storageOrganelle:setColour(ColourValue(0, 1, 0, 1))  
        self.currentMicrobe:addOrganelle(q, r, storageOrganelle)
        self.organelleCount = self.organelleCount + 1
    end
end


function MicrobeEditor:addMovementOrganelle(organelleType)
    local q, r = self:getMouseHex()
    if self.currentMicrobe:getOrganelleAt(q, r) == nil then
        -- Calculate the momentum of the movement organelle based on angle towards nucleus
        local organelleX, organelleY = axialToCartesian(q, r)
        local nucleusX, nucleusY = axialToCartesian(0, 0)
        local deltaX = nucleusX - organelleX
        local deltaY = nucleusY - organelleY
        local dist = math.sqrt(deltaX^2 + deltaY^2) -- For normalizing vector
        local momentumX = deltaX / dist * FLAGELIUM_MOMENTUM
        local momentumY = deltaY / dist * FLAGELIUM_MOMENTUM
        local movementOrganelle = MovementOrganelle(
            Vector3(momentumX, momentumY, 0.0),
            300
        )
        movementOrganelle:addHex(0, 0)
        movementOrganelle:setColour(ColourValue(0.8, 0.3, 0.3, 1))
        self.currentMicrobe:addOrganelle(q,r, movementOrganelle)
        self.organelleCount = self.organelleCount + 1
    end
end

function MicrobeEditor:addProcessOrganelle(organelleType)
    local q, r = self:getMouseHex()
    if self.currentMicrobe:getOrganelleAt(q, r) == nil then
        local processOrganelle = ProcessOrganelle()
        if organelleType == "mitochondria" then         
            processOrganelle:addProcess(global_processMap["Respiration"])
            processOrganelle:addHex(0, 0)
            processOrganelle:setColour(ColourValue(0.8, 0.4, 0.5, 0))
            
            self.currentMicrobe:addOrganelle(q,r, processOrganelle)
        else
            assert(false, "organelleType did not exist")
        end
    end
    self.organelleCount = self.organelleCount + 1
end

function MicrobeEditor:addAgentVacuole(organelleType)
    if organelleType == "toxin" then         
        local q, r = self:getMouseHex()
        if self.currentMicrobe:getOrganelleAt(q, r) == nil then
            local agentVacuole = AgentVacuole(CompoundRegistry.getCompoundId("oxytoxy"), global_processMap["OxyToxySynthesis"])
            agentVacuole:addHex(0, 0)
            agentVacuole:setColour(ColourValue(0, 1, 1, 0))
            self.currentMicrobe:addOrganelle(q, r, agentVacuole)
            self.organelleCount = self.organelleCount + 1
        end
    end
    self.organelleCount = self.organelleCount + 1
end

function MicrobeEditor:addNucleus()
    local nucleusOrganelle = NucleusOrganelle()
    nucleusOrganelle:addHex(0, 0)
    nucleusOrganelle:setColour(ColourValue(0.8, 0.2, 0.8, 1))
    self.currentMicrobe:addOrganelle(0, 0, nucleusOrganelle)
    nucleusOrganelle:addProcess(global_processMap["ReproductaseSynthesis"])
    nucleusOrganelle:addProcess(global_processMap["AminoAcidSynthesis"])
end

function MicrobeEditor:createNewMicrobe()
    self.organelleCount = 0
    if self.currentMicrobe ~= nil then
        self.currentMicrobe.entity:destroy()
    end
    self.currentMicrobe = Microbe.createMicrobeEntity(nil, false)
    self.currentMicrobe.entity:stealName("working_microbe")
    self.currentMicrobe.sceneNode.transform.orientation = Quaternion(Radian(Degree(180)), Vector3(0, 0, 1))-- Orientation
    self.currentMicrobe.sceneNode.transform:touch()
    self.currentMicrobe.collisionHandler:addCollisionGroup("powerupable")
    self:addNucleus()
    
end