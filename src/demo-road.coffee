define([
        'lib/dom'
        'lib/utils'
        'lib/debugger'
        'lib/render'
        'lib/game'
        'lib/stats'
        'settings/key'
        'settings/background'
        'settings/sprites'
        'settings/colors'],
    (DOM, Util, Debugger, Render, Game, Stats, KEY, BACKGROUND, SPRITES, COLORS)->

        fps = 60
        step = 1/fps
        width = 1024
        height = 768

        #init vars enterily of render in curves
        centrifugal = 0.3           #centrifugal force multiplier when going around curves
        offRoadDecel = 0.99         #speed multiplier when off road (e.g you lose 2% speed each update frame)
        skySpeed = 0.001            #background sky layer scroll speed when going around curve (or up hill)
        hillSpeed = 0.002           #background hill layer scroll speed when going around curve (or up hill)
        treeSpeed = 0.003           #background tree layer scroll speed when going around curve (or up hill)
        skyOffset = 0               #current sky scroll offset
        hillOffset = 0              #current hill scroll offset
        treeOffset = 0              #current tree scroll offset
        #end vars of render curves

        segments = []
        cars = []
        stats = Game.stats('fps')
        canvas = DOM.get('canvas')
        ctx = canvas.getContext('2d')
        background = null
        sprites = null
        resolution = null
        roadWidth = 2000
        segmentLength = 200
        rumbleLength = 3
        trackLength = null
        lanes = 3
        fieldOfView = 100
        camHeight = 1000
        camDepth = null
        drawDistance = 300
        playerX = 0
        playerZ = null
        fogDensity = 5
        position = 0
        speed = 0
        maxSpeed = segmentLength/step
        accel = maxSpeed/5
        breaking = -maxSpeed
        decel = -maxSpeed/5
        offRoadDecel = -maxSpeed/2
        offRoadLimit = maxSpeed/4

        totalCars = 20
        currentLapTime = 0
        lastLapTime = null

        keyLeft = false
        keyRight = false
        keyFaster = false
        keySlower = false

        #FOR HUD
        hud = 
            speed:
                value: null
                dom: DOM.get 'speed_value'
            current_lap_time:
                value: null
                dom: DOM.get 'current_lap_time_value'
            last_lap_time:
                value: null
                dom: DOM.get 'last_lap_time_value'
            fast_lap_time:
                value: null
                dom: DOM.get 'fast_lap_time_value'

        #GLOBAL SETTING FOR THIS ESPECIAL ROAD
        ROAD =
            LENGTH:
                NONE: 0
                SHORT: 25
                MEDIUM: 50
                LONG: 100
            HILL:
                NONE: 0
                LOW: 20
                MEDIUM: 40
                HIGH: 60
            CURVE:
                NONE: 0
                EASY: 2
                MEDIUM: 4
                HARD: 6
        ###################################################
        #Update the game world
        ###################################################
        update = (dt)->

            playerSegment = findSegment(position + playerZ)
            playerW = SPRITES.PLAYER_STRAIGHT.w * SPRITES.SCALE
            speedPercent = speed/maxSpeed
            dx = dt * 2 * speedPercent
            startPosition = position

            updateCars dt, playerSegment, playerW

            position = Util.increase(position, dt * speed, trackLength)

            if keyLeft
                playerX = playerX - dx
            else if keyRight
                playerX = playerX + dx

            #update the player coordinate's of axis X
            playerX = playerX - (dx * speedPercent * playerSegment.curve * centrifugal)

            if keyFaster
                speed = Util.accelerate speed, accel, dt
            else if keySlower
                speed = Util.accelerate speed, breaking, dt
            else
                speed = Util.accelerate speed, decel, dt

            #Increase the offsets of the sky, hill and tree
            skyOffset = Util.increase(skyOffset, skySpeed * playerSegment.curve * speedPercent, 1)
            hillOffset = Util.increase(hillOffset, hillSpeed * playerSegment.curve * speedPercent, 1)
            treeOffset = Util.increase(treeOffset, treeSpeed * playerSegment.curve * speedPercent, 1)

            if ( (playerX < -1) or (playerX > 1) )

                if (speed > offRoadLimit)
                    speed = Util.accelerate speed, offRoadDecel, dt

                nPSegment = 0
                while nPSegment < playerSegment.sprites.length
                    sprite = playerSegment.sprites[nPSegment]
                    spriteW = sprite.source.w * SPRITES.SCALE
                    if Util.overlap playerX, playerW, sprite.offset + spriteW/2 * (if sprite.offset > 0 then 1 else -1), spriteW
                        speed = maxSpeed/5
                        position = Util.increase playerSegment.p1.world.z, -playerZ, trackLength
                        break
                    nPSegment++

            #render the way of the cars
            nPSegmentCar = 0
            while nPSegmentCar < playerSegment.cars.length
                car = playerSegment.cars[nPSegmentCar]
                carW = car.sprite.w * SPRITES.SCALE
                if speed > car.speed
                    if Util.overlap playerX, playerW, car.offset, carW, 0.8
                        speed = car.speed * (car.speed / speed)
                        position = Util.increase car.z, -playerZ, trackLength
                        break
                nPSegmentCar++

            playerX = Util.limit playerX, -2, 2 #dont ever let player go too far out the bounds
            speed = Util.limit speed, 0, maxSpeed

            if position > playerZ
                if currentLapTime and (startPosition < playerZ)
                    lastLapTime = currentLapTime
                    currentLapTime = 0
                    if lastLapTime <= Util.toFloat Dom.storage.fast_lap_time
                        Dom.storage.fast_lap_time = lastLapTime
                        updateHud('fast_lap_time', formatTime(lastLapTime))
                        Dom.addClassName 'fast_lap_time', 'fastest'
                        Dom.addClassName 'last_lap_time', 'fastest'
                    else
                        Dom.removeClassName 'fast_lap_time', 'fastest'
                        Dom.removeClassName 'last_lap_time', 'fastest'

                    updateHud 'last_lap_time', formatTime lastLapTime
                    Dom.show 'last_lap_time'
                else
                    currentLapTime+= dt

            updateHud 'speed', 5 * Math.round(speed/5000)
            updateHud 'current_lap_time', formatTime(currentLapTime)
            return

        updateCars = (dt, playerSegment, playerW)->
            nCars = 0
            while nCars < cars.length
                car = cars[nCars]
                oldSegment = findSegment car.z
                car.offset = car.offset + updateCarOffset car, oldSegment, playerSegment, playerW
                car.z = Util.increase car.z, dt * car.speed, trackLength
                car.percent = Util.percentRemaining car.z, segmentLength
                newSegment = findSegment car.z
                if oldSegment isnt newSegment
                    index = oldSegment.cars.indexOf car
                    oldSegment.cars.splice index, 1
                    newSegment.cars.push car
                nCars++

        updateCarOffset = (car, carSegment, playerSegment, playerW)->

            lookahead = 20
            carW = car.sprite.w * SPRITES.SCALE

            if ( carSegment.index - playerSegment.index ) > drawDistance
                return 0
            iLook = 0
            while iLook < lookahead
                segment = segments[(carSegment.index+iLook)%segments.length]

                if segment is playerSegment and car.speed > speed and Util.overlap playerX, playerW, car.offset, carW, 1.2
                    if playerX > 0.5
                        dir = -1
                    else if playerX < -0.5
                        dir = 1
                    else
                        dir = (if car.offset > playerX then 1 else -1) 
                    return dir * 1/iLook * (car.speed-speed)/maxSpeed

                jSegCar = 0
                while jSegCar < segment.cars.length
                    otherCar = segment.cars[jSegCar]
                    otherCarW = otherCar.sprite.w * SPRITES.SCALE
                    if car.speed > otherCar.speed and Util.overlap car.offset, carW, otherCar.offset, otherCarW, 1.2
                        if otherCar.offset > 0.5
                            dir = -1
                        else if otherCar.offset < -0.5
                            dir = 1
                        else
                            dir = (if car.offset > otherCar.offset then 1 else -1)
                        return dir * 1/iLook * (car.speed - otherCar.speed)/maxSpeed
                    jSegCar++

                iLook++
            #if no cars ahead, but I have somehow ended up off road, then steer back on
            if (car.offset < -0.9)
                return 0.1
            else if (car.offset > 0.9)
                return -0.1
            else 
                return 0

        updateHud = (key, value)->
            if hud[key].value isnt value
                hud[key].value = value
                DOM.set hud[key].dom, value
            return

        formatTime = (dt)->
            minutes = Math.floor dt/60
            seconds = Math.floor dt - (minutes * 60)
            tenths = Math.floor 10 * (dt - Math.floor(dt))

            if minutes > 0
                return "#{minutes }.#{(if seconds < 10 then 0 else "" )+ seconds}.#{tenths}" 
            else
                return "#{seconds}.#{tenths}"

        ##################################################
        #Render the game world
        ###################################################
        render = ()->

            baseSegment = findSegment position
            basePercent = Util.percentRemaining position, segmentLength
            playerSegment = findSegment position+playerZ
            playerPercent = Util.percentRemaining position+playerZ, segmentLength
            playerY = Util.interpolate playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent
            maxy = height

            x = 0
            dx = -(baseSegment.curve * basePercent)

            ctx.clearRect 0, 0, width, height
            
            #render only background
            Render.background ctx, background, width, height, BACKGROUND.SKY, skyOffset, resolution * skySpeed * playerY
            Render.background ctx, background, width, height, BACKGROUND.HILLS, hillOffset, resolution * hillSpeed * playerY
            Render.background ctx, background, width, height, BACKGROUND.TREES, treeOffset, resolution * treeSpeed * playerY

            n = 0
            while n < drawDistance
                #get a segment of the segment collection
                segment = segments[(baseSegment.index + n) % segments.length]
                segment.looped = segment.index < baseSegment.index
                segment.fog = Util.exponentialFog(n/drawDistance, fogDensity)

                Util.project segment.p1, 
                             ( playerX * roadWidth ) - x, 
                             playerY + camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth

                Util.project segment.p2, 
                             ( playerX * roadWidth ) - x - dx, 
                             playerY + camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth
                             
                x = x + dx
                dx = dx + segment.curve

                #WARNING
                #======
                #ever makes the next segment of road
                #this conditional ever return true for create more segments when looping
                n++
                if (segment.p1.camera.z <= camDepth) or 
                   (segment.p2.screen.y >= segment.p1.screen.y) or
                   (segment.p2.screen.y >= maxy)
                    continue

                Render.segment ctx, width, lanes,
                                segment.p1.screen.x,
                                segment.p1.screen.y,
                                segment.p1.screen.w,
                                segment.p2.screen.x,
                                segment.p2.screen.y,
                                segment.p2.screen.w,
                                segment.fog,
                                segment.color

                maxy = segment.p2.screen.y

            nDrawDis = drawDistance - 1
            while nDrawDis-- 
                segment = segments[(baseSegment.index + nDrawDis)%segments.length]

                nSegmentCar = 0
                while nSegmentCar < segment.cars.length
                    car = segment.cars[nSegmentCar]
                    sprite = car.sprite
                    spriteScale = Util.interpolate segment.p1.screen.scale, segment.p2.screen.scale, car.percent
                    spriteX = Util.interpolate(segment.p1.screen.x, segment.p2.screen.x, car.percent) +
                        (spriteScale * car.offset * roadWidth * width/2)
                    spriteY = Util.interpolate(segment.p1.screen.y, segment.p2.screen.y, car.percent)

                    Render.sprite ctx, width, height, resolution,
                        roadWidth,sprites, car.sprite, spriteScale,
                        spriteX, spriteY, -0.5, -1, segment.clip

                    nSegmentCar++

                nSegmentSprite = 0
                while nSegmentSprite < segment.sprites.length
                    sprite = segment.sprites[nSegmentSprite]
                    spriteScale = segment.p1.screen.scale
                    spriteX = segment.p1.screen.x + (spriteScale * sprite.offset * roadWidth * width/2)
                    spriteY = segment.p1.screen.y
                    Render.sprite ctx, width, height, resolution,
                        roadWidth, sprites, sprite.source, spriteScale,
                        spriteX, spriteY, (if sprite.offset < 0 then -1 else 0), -1
                        segment.clip
                    nSegmentSprite++

                if segment == playerSegment
                    Render.player ctx, width, height, resolution, roadWidth, sprites,
                        speed/maxSpeed, camDepth/playerZ,
                        width/2,
                        (height/2) - (camDepth/playerZ * Util.interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent)) * height/2,
                        speed * (if keyLeft then -1 else if keyRight then 1 else 0),
                        playerSegment.p2.world.y - playerSegment.p1.world.y
            return

        ###################################################
        #Build Road Geometry
        ###################################################
        lastY = ()->
            if segments.length is 0 then 0 else segments[segments.length - 1].p2.world.y

        addSprite = (n, sprite, offset)->
            segments[n].sprites.push({
                source: sprite
                offset: offset
            })
            return

        addSegment = (curve, y)->
            n = segments.length
            segments.push
                index: n
                p1: 
                    world:
                        y: lastY()
                        z: n * segmentLength
                    camera:{}
                    screen:{}
                p2:
                    world:
                        y: y
                        z: (n+1) * segmentLength
                    camera:{}
                    screen:{}
                curve: curve
                sprites: []
                cars: []
                color: if Math.floor(n/rumbleLength)%2 then COLORS.DARK else COLORS.LIGHT
            return

        addRoad = (enter, hold, leave, curve, y)->
            startY = lastY()
            endY = startY + ( Util.toInt(y, 0) * segmentLength )
            total = enter + hold + leave
            nEnter = 0
            nHold = 0
            nLeave = 0
            while nEnter < enter
                addSegment Util.easeIn(0, curve, nEnter/enter), Util.easeInOut(startY, endY, nEnter/total)
                nEnter++
            while nHold < hold
                addSegment curve, Util.easeInOut(startY, endY, (enter+nHold)/total)
                nHold++
            while nLeave < leave
                addSegment Util.easeInOut(curve, 0, nLeave/leave), Util.easeInOut(startY, endY, (enter+hold+nLeave)/total)
                nLeave++
            return

        addStraight = (n)->
            num = n or ROAD.LENGTH.MEDIUM
            addRoad(num, num, num, 0, 0)
            return

        addHill = (n, h) ->
            num = n or ROAD.LENGTH.MEDIUM
            _height = h or ROAD.HILL.MEDIUM
            addRoad(num, num, num, 0, _height)
            return

        addCurve = (n, c, h) ->
            num = n or ROAD.LENGTH.MEDIUM
            curve = c or ROAD.CURVE.MEDIUM
            _height = h or ROAD.HILL.NONE
            addRoad(num, num, num, curve, _height)
            return
            
        addLowRollingHills = (n, h)->
            num = n or ROAD.LENGTH.SHORT
            _height = h or ROAD.HILL.LOW
            addRoad num, num, num, 0, _height/2
            addRoad num, num, num, 0, -_height
            addRoad num, num, num, 0, _height
            addRoad num, num, num, 0, 0
            addRoad num, num, num, 0, _height/2
            addRoad num, num, num, 0, 0
            return

        addSCurves = () ->
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.NONE
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY, -ROAD.HILL.LOW
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY, ROAD.HILL.MEDIUM
            addRoad ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM, -ROAD.HILL.MEDIUM
            return

        addDownhillToEnd = (n)->
            num = n or 200
            addRoad num, num, num, -ROAD.CURVE.EASY, -lastY()/segmentLength
            return

        addBumps = ()->
            addRoad 10, 10, 10, 0, 5
            addRoad 10, 10, 10, 0, -2
            addRoad 10, 10, 10, 0, -5
            addRoad 10, 10, 10, 0, 8
            addRoad 10, 10, 10, 0, 5
            addRoad 10, 10, 10, 0, -7
            addRoad 10, 10, 10, 0, 5
            addRoad 10, 10, 10, 0, -2
            return

        resetRoad = ()->
            segments = []

            addStraight ROAD.LENGTH.SHORT
            addLowRollingHills()
            addSCurves()
            addCurve ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW
            addBumps()
            addLowRollingHills()
            addCurve ROAD.LENGTH.LONG*2, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM
            addStraight()
            addCurve ROAD.LENGTH.MEDIUM, ROAD.HILL.HIGH
            addSCurves()
            addCurve ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM, ROAD.HILL.NONE
            addHill ROAD.LENGTH.LONG, -ROAD.HILL.HIGH
            addCurve ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW
            addBumps()
            addHill(ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM)
            addStraight()
            addSCurves()
            addDownhillToEnd()

            resetSprites()
            resetCars()

            segments[findSegment(playerZ).index + 2].color = COLORS.START
            segments[findSegment(playerZ).index + 3].color = COLORS.START

            nRumble = 0
            while nRumble < rumbleLength
                segments[ segments.length - 1 - nRumble ].color = COLORS.FINISH
                nRumble++

            trackLength = segments.length * segmentLength
            return

        findSegment = (z)->
            segments[Math.floor(z/segmentLength) % segments.length]

        resetSprites = ()->
            addSprite 20, SPRITES.BILLBOARD07, -1
            addSprite 40, SPRITES.BILLBOARD06, -1
            addSprite 60, SPRITES.BILLBOARD08, -1
            addSprite 80, SPRITES.BILLBOARD09, -1
            addSprite 100, SPRITES.BILLBOARD01, -1
            addSprite 120, SPRITES.BILLBOARD02, -1
            addSprite 140, SPRITES.BILLBOARD03, -1
            addSprite 160, SPRITES.BILLBOARD04, -1
            addSprite 180, SPRITES.BILLBOARD05, -1

            addSprite 240, SPRITES.BILLBOARD07, -1.2
            addSprite 240, SPRITES.BILLBOARD06, 1.2
            addSprite segments.length - 25, SPRITES.BILLBOARD07, -1.2
            addSprite segments.length - 25, SPRITES.BILLBOARD06, 1.2

            nOne = 10
            while nOne < 200
                addSprite nOne, SPRITES.PALM_TREE, 0.5 + Math.random()*0.5
                addSprite nOne, SPRITES.PALM_TREE, 1 + Math.random()*2
                nOne += 4 + Math.floor(nOne/100)

            nTwo = 250
            while nTwo < 1000
                addSprite nTwo, SPRITES.COLUMN, 1.1
                addSprite nTwo + Util.randomInt(0,5), SPRITES.TREE1, -1 - (Math.random() * 2)
                addSprite nTwo + Util.randomInt(0,5), SPRITES.TREE2, -1 - (Math.random() * 2)
                nTwo+=5

            nThree = 200
            while nThree < segments.length
                addSprite nThree, Util.randomChoice SPRITES.PLANTS, Util.randomChoice([1, -1]) * ( 2 + Math.random() * 5 )
                nThree+=3

            nFour = 1000
            while nFour < (segments.length - 50)
                side = Util.randomChoice [1, -1]
                addSprite nFour + Util.randomInt(0,50), Util.randomChoice(SPRITES.BILLBOARDS), -side
                interI = 0
                while interI < 20
                    sprite = Util.randomChoice SPRITES.PLANTS
                    offset = side * (1.5 + Math.random())
                    addSprite nFour + Util.randomInt(0, 50), sprite, offset
                    interI++
                nFour+=100

        resetCars = ()->
            cars = []
            nCars = 0
            while nCars < totalCars
                offset = Math.random() * Util.randomChoice([-0.8, 0.8])
                z = Math.floor(Math.random() * segments.length) * segmentLength
                sprite = Util.randomChoice(SPRITES.CARS)
                speed = maxSpeed/4 + Math.random() * maxSpeed/(if speed == SPRITES.SEMI then 4 else 2)
                car = 
                    offset: offset
                    z: z
                    sprite: sprite
                    speed: speed
                segment = findSegment(car.z)
                segment.cars.push(car)
                cars.push(car)
                nCars++
        ###################################################
        #THE GAME LOOP
        ###################################################
        Game.run({
            canvas: canvas
            render: render
            update: update
            stats: stats
            step: step
            imgs: ["background", "sprites"]
            keys: [
                { keys: [KEY.LEFT,  KEY.A], mode: 'down', action: ()-> keyLeft   = true;return},
                { keys: [KEY.RIGHT, KEY.D], mode: 'down', action: ()-> keyRight  = true;return},
                { keys: [KEY.UP,    KEY.W], mode: 'down', action: ()-> keyFaster = true;return},
                { keys: [KEY.DOWN,  KEY.S], mode: 'down', action: ()-> keySlower = true;return},
                { keys: [KEY.LEFT,  KEY.A], mode: 'up',   action: ()-> keyLeft   = false;return},
                { keys: [KEY.RIGHT, KEY.D], mode: 'up',   action: ()-> keyRight  = false;return},
                { keys: [KEY.UP,    KEY.W], mode: 'up',   action: ()-> keyFaster = false;return},
                { keys: [KEY.DOWN,  KEY.S], mode: 'up',   action: ()-> keySlower = false;return}
            ]
            ready:(images)->
                background = images[0]
                sprites = images[1]
                reset()
                return
        })

        reset = (opts)->
            options = opts or {}
            canvas.width = width = Util.toInt(options.width, width)
            canvas.height = height = Util.toInt(options.height, height)
            lanes = Util.toInt(options.lanes, lanes)
            roadWidth = Util.toInt(options.roadWidth, roadWidth)
            camHeight = Util.toInt(options.camHeight, camHeight)
            drawDistance = Util.toInt(options.drawDistance, drawDistance)
            fogDensity = Util.toInt(options.fogDensity, fogDensity)
            fieldOfView = Util.toInt(options.fieldOfView, fieldOfView)
            segmentLength = Util.toInt(options.segmentLength, segmentLength)
            rumbleLength = Util.toInt(options.rumbleLength, rumbleLength)
            camDepth = 1 / Math.tan( (fieldOfView/ 2) * Math.PI / 180)
            playerZ = camHeight * camDepth
            resolution = height / 480

            if( ( segments.length is 0 ) or ( options.segmentLength ) or ( options.rumbleLength ))
                resetRoad()
            return
        return
)
