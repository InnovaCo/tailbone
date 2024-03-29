window.Inn ?= {}

#### *class* Inn.View
#
#---
# Класс представления
# 
Inn.View = Backbone.View.extend({


  ##### initialize( *options*, *partials* )
  #
  #---
  # Конструктор
  # 
  # **options** - Хеш с настройками
  # 
  # **partials** - Хеш с конфигурацией partial-ов
  initialize: (options, @partials = null) ->
    @partials = (@partials ? @options.partials) ? []

    ##### children
    #
    #---
    # Коллекция с дочерними View
    @children = new Inn.ViewsCollection
   
    ##### _parent
    #
    #---
    # Родительский View
    @_parent = null

    ##### ready
    #
    #---
    # Отражает состояние View
    @ready = off

    ##### _rendering
    #
    #---
    # Отражает состояние рендеринга View
    @_rendering = off


  ##### destroy()
  #
  #---
  # Уничтожает View и всех его детей
  #
  # Генерирует событие **destroyed**
  destroy: ->
    # Уничтожаем ссылку на родителя
    @parent = null
    # Вычищаем руками все подписки на события
    @undelegateEvents()
    # Удаляем корневой элемент из DOM
    # @remove
    # Вычищаем детей
    @children.destroy()
    # Генерируем событие destroyed
    @trigger 'destroyed', @
    @off "ready"

    return @

    
  ##### render(skipChildren)
  #
  #---
  # Рендерит View и всех его детей
  #
  # **skipChildren** - Не выполняет рендеринг partials, при этом добавляя их в children
  render: (skipChildren = off, replaceContext = on) ->
    @stopRender() if @_rendering

    @_rendering = on

    # Переопределяем имя шаблона, если оно задано в data-view-template
    @options.templateName = this.$el.data('view-template') if this.$el.data('view-template')?

    @_loadTemplate (template) =>
      # Если это необходимо, подгружаем недостающие i18n bundles
      require @options.i18nRequire ? [], =>
        # Получаем данные для рендеринга шаблона
        # @todo: написать тесты!
        @_$memorizedEl = @$el
        @$el = @$el.clone on, on
        @el = @$el.get()

        @$el.html template @options.model?.toJSON() ? @options.dataManager?.getDataAsset() ? {}

        # Унаследованные опции с очищенным полем partials
        patchedOptions = _.clone(@options)
        patchedOptions.partials = []

        # Добавляем partials в очередь рендеринга
        for partial, idx in @partials
          foundPartial = @children.get partial.id ? partial.cid
          $ctx = @$el.find("##{partial.id}")

          if foundPartial?
            foundPartial.setElement $ctx
          else
            # Если View передана в виде экземпляра Backbone.View,
            # просто устанавливаем ему корневой элемент
            if partial instanceof Inn.View
              view = partial
              view.options = _.extend {}, patchedOptions, view.options
              view.setElement $ctx.get(0)
            # Если передан конфиг-хеш, создаём новый объект Inn.View
            else
              view = new Inn.View _.extend {}, patchedOptions, { el: $ctx.get(0) }, partial

            # Устанавливаем родителя
            view._parent = @

            # Добавляем в очередь на рендеринг
            @children.add view

        # Вытаскиваем детей
        for child, idx in @pullChildren()
          @initPartial child, patchedOptions, off

        # Если нет partial-ов или их рендеринг запрещён, генериуем событие **ready**
        if skipChildren or @children.isEmpty()
          # Устанавливаем флажок ready в true, если элемент не корневой
          unless @isRoot()
            @ready = on

          @_rendering = off

          if replaceContext
            @replaceContext()
          else
            @trigger 'readyForReplacement', @

          @trigger 'ready'
        else
          # Ожидаем завершения рендеринга **partial**-ов
          @children.on 'ready', _.bind(@_readyHandler, @, replaceContext)

          @children.render()

    return @

  ##### initPartial(*el*, *config*, *silent*)
  #
  #---
  # Создаёт дочерний View из DOM-элемента
  initPartial: (el, config = {}, silent = off) ->
    $ctx = $(el)
    $ctx.removeClass @options.partialClassName
    view = new Inn.View _.extend {}, config, { el: $ctx.get(0), id: $ctx.attr('id') }, $ctx.data('view-options')
    view._parent = @
    view.$el.addClass @options.partialClassName # Оставляем напоминание, что это partial
    @children.add view unless silent
    return view

  replaceContext: ->
    @_$memorizedEl.replaceWith @$el
    @_$memorizedEl = undefined

  ##### _readyHandler()
  #
  #---
  # Обработчик завершения рендеринга
  # 
  _readyHandler: (replaceContext) -> 
    # Устанавливаем флажок ready в true, если элемент не корневой
    unless @isRoot()
      @ready = on

    # Сбрасываем статус рендеринга дочерних View
    @children.reset()
    # Снимаем блокировку рендеринга
    @_rendering = off

    if replaceContext
      @replaceContext()
    else
      @trigger 'readyForReplacement', @

    @trigger 'ready'

  ##### stopRender()
  #
  #---
  # Прекращает рендеринг шаблонов
  # 
  stopRender: ->
    @_rendering = off
    # Отписываемся от события завершения рендеринга
    @off 'ready', @_readyHandler, @

    # Отписываемся от события завершения 
    # рендеринга у всех детей
    @children.stopRender()

    return @


  ##### _loadTemplate( *callback* )
  #
  #---
  # Загружает шаблон View
  # 
  # **callback** - Колбэк
  _loadTemplate: (callback) ->
    template = =>
        try
          return jade.templates[@_getTemplateName()].apply null, arguments
        catch e
          if typeof window.console isnt 'undefined' and typeof window.console.debug is 'function'
            console.debug "tailbone view error [#{@_getTemplateName()}]:", e.toString()

          return ''

    if jade.templates[@_getTemplateName()]?
      setTimeout ->
        callback.call @, template
    else
      req = $.getScript @_getTemplateURL(), =>
        callback.call @, template

      req.fail =>
        callback.call @, -> ''

        if typeof window.console is 'object' and typeof window.console.warn is 'function'
          console.warn "tailbone: failed to load template '#{@_getTemplateName()}' from '#{@_getTemplateURL()}'"

    return @

  ##### _getTemplateURL()
  #
  #---
  # Определяет URL шаблона
  _getTemplateURL: ->
    divider = if @options.templateFolder then '/' else ''
    return @options.templateFolder + divider + @_getTemplateName() + '.' + @options.templateFormat unless @options.templateURL?
    return @options.templateURL
  
  ##### _getTemplateName()
  #
  #---
  # Определяет название шаблона
  _getTemplateName: ->
    return 'b'+ @id[0].toUpperCase() + @id.slice(1) unless @options.templateName
    return @options.templateName


  ##### pullChildren()
  #
  #---
  # Вытаскивает pratials из отрендеренного шаблона
  pullChildren: ->
    # Для создания вью по "дырке" используем класс options.partialClassName
    # 
    # Для оверрайдинга опций используем data-атрибут (data-view-options)
    # 
    # Для оверрайдинга имени шаблона используем data-атрибут (data-view-template)
    # 
    # ID берём из атрибута id
    return @$el.find ".#{@options.partialClassName}"

  ##### reInitPartial()
  #
  #---
  # Повторно инициализирует View
  #
  reInitPartial: (view) ->
    options = view.options
    @children.remove(view)
    @children.add @initPartial(view.$el, options).render()
    view.destroy()

##### isRoot()
  #
  #---
  # Устанавливает, является ли этот View корневым
  isRoot: ->
    return @_parent is null

  # Заменяем только один конкретный partial
  replacePartial: (oldID, newType) ->
    # Проверяем, есть ли вообще "дырка", которую надо заменять.
    oldPartial = @children.get(oldID)
    return false unless oldPartial

    _this = @
    # Проверяем, загружен ли вообще новый View,
    # и подгружаем, если нет.
    require [newType], (newPartialClass) =>
      newPartial = new newPartialClass
        model: _this.options.model
        l4g: _this.options.l4g
        moduleNotify: _this.options.moduleNotify

      newPartial.on "ready", =>
        _this.replacePartialFinishStep.call(_this, oldID, newPartial)

      newPartial.$el
        .attr("id", newPartial.options.id)
        .attr("data-view-template", newPartial.options.templateName)
        .data("view-template", newPartial.options.templateName)
        .addClass("bPartial")

      newPartial.render()

    return @  # поддерживаем chainable

  replacePartialFinishStep: (oldID, newPartial) ->
    # ОЧЕНЬ ВАЖНО! За это время "дырка" могла измениться, берем заново.
    oldPartial = @children.get(oldID)
    return false if not oldPartial

    newPartial.$el.replaceAll oldPartial.$el

    @children.remove oldPartial
    @children.add newPartial

    oldPartial.destroy()
    oldPartial = null
    newPartial.off "ready"

    # FIXME move out this hack
    if newPartial.id isnt "bGamePanel__settings"
      $( document ).trigger "game-panel-rendered"
    return @

  # У нас на входе есть только шаблон. (ну не нужно нам ничего специального, например)
  # В таком случае создаем под него дефолтное view.
  #
  _replaceTemplate: (oldID, newTemplateName) ->
    # Проверяем, есть ли вообще дырка, которую надо заменять.
    oldPartial = @children.get(oldID)
    return false unless oldPartial

    newView = new Inn.View _.extend {}, oldPartial.options,
      templateName: newTemplateName

    newView.on "ready", =>
      _this.replacePartialFinishStep.call(_this, oldID, newView)

    newView.$el
      .attr("data-view-template", newView.options.templateName)
      .data("view-template", newView.options.templateName)
      .addClass("bPartial")
    newView.render()

    return @

  ##### options
  #
  #---
  # Хеш настроек по умолчанию
  options:
    partialClassName: 'bPartial'
    templateFolder: ''
    templateFormat: 'js'


})
