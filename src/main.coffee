define([
        'lib/dom'
        'lib/utils'
        'lib/debugger'
        'lib/render'
        'lib/game'
        'lib/stats'
        'settings/key'
        'settings/background'
        'settings/colors'],
    (DOM, Util, Debugger, Render, Game, Stats, KEY, BACKGROUND, COLORS)->

        fps = 60
        step = 1/fps
        width = 1024
        height = 768
        segments = []
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

        keyLeft = false
        keyRight = false
        keyFaster = false
        keySlower = false


        ###################################################
        #Update the game world
        ###################################################
        update = (dt)->
            position = Util.increase(position, dt * speed, trackLength)
            dx = dt * 2 * (speed/maxSpeed)

            if keyLeft
                playerX = playerX - dx
            else if keyRight
                playerX = playerX + dx

            if keyFaster
                speed = Util.accelerate speed, accel, dt
            else if keySlower
                speed = Util.accelerate speed, breaking, dt
            else
                speed = Util.accelerate speed, decel, dt

            if ( (playerX < -1) or (playerX > 1) ) and (speed > offRoadLimit)
                speed = Util.accelerate speed, offRoadDecel, dt

            Debugger.element('speed', "speed: #{speed}")
            Debugger.element('position', "position: #{position}")

            playerX = Util.limit playerX, -2, 2
            speed = Util.limit speed, 0, maxSpeed
            return

        ###################################################
        #Render the game world
        ###################################################
        render = ()->
            baseSegment = findSegment position
            maxy = height

            ctx.clearRect 0, 0, width, height
            
            #render only background
            #Render.background ctx, background, width, height, BACKGROUND.SKY
            #Render.background ctx, background, width, height, BACKGROUND.HILLS
            #Render.background ctx, background, width, height, BACKGROUND.TREES

            n = 0
            segment = null

            while n < drawDistance
                #get a segment of the segment collection
                segment = segments[(baseSegment.index + n) % segments.length]

                segment.looped = segment.index < baseSegment.index
                segment.fog = Util.exponentialFog(n/drawDistance, fogDensity)

                Debugger.element('fog', "fog:#{segment.fog} ,  #{n}")
                Debugger.element('cameraz', "cameraZ:" + (position - (if segment.looped then trackLength else 0)))

                Util.project segment.p1, 
                             ( playerX * roadWidth ), 
                             camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth

                Util.project segment.p2, 
                             ( playerX * roadWidth ), 
                             camHeight, 
                             position - (if segment.looped then trackLength else 0),
                             camDepth, 
                             width, 
                             height, 
                             roadWidth

                Debugger.element('segment', segment)

                Debugger.element('segment.p1.camera.z', "segment.p1.camera.z:#{segment.p1.camera.z} ,  #{n}")
                Debugger.element('cameraDepth', "camDepth:#{camDepth}")
                Debugger.element('segment.p2.screen.y', "segment.p2.screen.y:#{segment.p2.screen.y}")
                Debugger.element('maxy', "Before maxy:#{maxy}")
                if (segment.p1.camera.z <= camDepth) or segment.p2.screen.y >= maxy
                    false

                ##unless ( segment.p1.camera.z >= camDepth ) or ( segment.p2.screen.y <= maxy )
                ##continue if ( segment.p1.camera.z <= camDepth ) or ( segment.p2.screen.y >= maxy )

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
                Debugger.element('maxy', "maxy:#{maxy}")
                n++

            Render.player ctx, width, height, resolution, roadWidth, sprites, speed/maxSpeed,
                            camDepth/playerZ,
                            width/2,
                            height,
                            speed * (if keyLeft then -1 else if keyRight then  1 else 0),
                            0
            return

        ###################################################
        #Build Road Geometry
        ###################################################
        resetRoad = ()->
            segments = []
            n = 0
            nRumble = 0
            #create a Collection of segments
            while n < 500
                segments.push
                    index: n
                    p1: 
                        world:
                            z: n * segmentLength
                        camera: {}
                        screen: {}
                    p2: 
                        world:
                            z: ( n + 1 ) * segmentLength
                        camera: {}
                        screen: {}
                    color: if ( Math.floor( n / rumbleLength) % 2 ) then COLORS.DARK else COLORS.LIGHT
                n++

            segments[findSegment(playerZ).index + 2].color = COLORS.START
            segments[findSegment(playerZ).index + 3].color = COLORS.START

            while nRumble < rumbleLength
                segments[ segments.length - 1 - nRumble ].color = COLORS.FINISH
                nRumble++

            trackLength = segments.length * segmentLength
            return

        findSegment = (z)->
            segments[Math.floor(z/segmentLength) % segments.length]

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
