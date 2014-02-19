define(->
    DOM = 
        get: (id)->
            if id instanceof HTMLElement or id is document then id else document.getElementById( id )

        set: (id, html) ->
            DOM.get(id).innerHTML = html

        on: (ele, type, fn, capture) ->
            DOM.get(ele).addEventListener(type, fn, capture)
            return

        un: (ele, type, fn, capture) ->
            DOM.get(ele).removeEventListener(type, fn, capture)

        show: (ele, type) ->
            DOM.get(ele).style.display = type or 'block'

        blur: (ev) ->
            ev.target.blur()

        addClassName: (ele, name)->
            DOM.toggleClassName(ele, name, true)

        removeClassName: (ele, name)->
            DOM.toggleClassName(ele, name, false)

        toggleClassName: (ele, name, flag)->
            ele = DOM.get(ele)
            classes = ele.className.split(' ')
            n = classes.indexOf(name)
            flag =  if flag? ( n < 0 ) else flag

            if flag and n < 0
                classes.push(name)
            else if on? and n >= 0
                classes.splice(n, 1)

            ele.className = classes.join ' '

        storage: window.localStorage or {}
    return DOM
)
