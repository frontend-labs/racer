define([
        'lib/stats',
        'lib/dom', 
        'lib/utils'], 
    (Stats, DOM, Util)->
        Game =
            run:(opts)->
                Game.loadImgs opts.imgs, (image)->

                    opts.ready(image)

                    Game.setKeyListener(opts.keys)

                    canvas = opts.canvas
                    update = opts.update
                    render = opts.render
                    step = opts.step
                    stats = opts.stats
                    now = null
                    last = Util.timestamp()
                    dt = 0
                    gdt = 0
                    frame = ()->
                        now = Util.timestamp()
                        dt = Math.min(1, (now - last) / 1000)
                        gdt = gdt + dt
                        while gdt > step
                            gdt = gdt - step
                            update(step)
                        render()
                        stats.update()
                        last = now
                        requestAnimationFrame(frame, canvas)
                        return
                    frame()
                    return
                return
                #Game.playMusic()

            loadImgs:(names, callback)->
                result = []
                count = names.length
                onload = ()->
                    if --count is 0
                        callback(result)
                    return

                for name in names by 1
                    result[_i] = document.createElement 'img'
                    DOM.on result[_i], 'load', onload
                    result[_i].src = "images/#{name}.png"
                return

            setKeyListener:(keys)->
                onKey = (keyCode, mode)->
                    i = 0
                    while i < keys.length
                        item = keys[i]
                        item.mode = item.mode or 'up'
                        if ( item.key is keyCode ) or ( item.keys and item.keys.indexOf(keyCode) >= 0 )
                            if item.mode is mode
                                item.action.call()
                        i++
                DOM.on(document, 'keydown', (ev)-> onKey(ev.keyCode, 'down'))
                DOM.on(document, 'keyup', (ev)-> onKey(ev.keyCode, 'up'))
                return

            stats: (parentId, id)->
                result = new Stats()
                result.domElement.id = id or 'stats'
                DOM.get(parentId).appendChild(result.domElement)

                msg = document.createElement('div')
                msg.style.cssText = "border: 2px solid gray; padding: 5px; margin-top: 5px; text-align: left; font-size: 1.15em; text-align:right;"
                msg.innerHTML = "Your canvas performance is"
                DOM.get(parentId).appendChild(msg)

                value = document.createElement('span')
                value.innerHTML = "..."
                msg.appendChild(value)

                setInterval(->
                    fps = result.current()
                    ok = if fps > 50 then 'good' else if fps < 30 then 'bad' else 'ok'
                    color = if fps > 50 then 'green' else if fps < 30 then 'red' else 'gray'
                    value.innerHTML = ok
                    value.style.color = color
                    msg.style.borderColor = color
                , 5000)

                return result

            playMusic: ()->
                music = DOM.get('music')
                music.loop = true
                music.volume = 0.05
                music.muted = DOM.storage.muted is true
                music.play()
                DOM.toggleClassName('mute', 'on', music.muted)
                DOM.on('mute', 'click', ->
                    DOM.storage.muted = music.muted = !music.muted
                    DOM.toggleClassName('mute', 'on', music.muted)
                )
                return

        return Game
)
