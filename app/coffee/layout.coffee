window.Inn ?= {}

#### *class* Inn.Layout
#
#---
# Менеджер представлений
# 
Inn.Layout = Inn.View.extend


  ##### initialize( *options* )
  #
  #---
  # Создаёт экземпляр менеджера представлений
  initialize: (options) ->
    
    throw new Inn.Error('dataManager should be in options') unless options && options.dataManager && options.dataManager instanceof Inn.DataManager
    
    @options = $.extend true, {}, Inn.Layout.defaults, options
    @_dataManager = options.dataManager
    @_views = []
    @_viewsUnrendered = 0
    
    @id = if @options.id then @options.id else 'layout'
    
    # Умееть генерировать события (Backbone.Events)
    _.extend(this, Backbone.Events)

  ##### render()
  #
  #---
  # Рендерит шаблон, возврашает deferred object
  render: ->
    # Если представления уже рендерятся, вернёт deferred object с текущим состоянием
    if @_renderDeferred and @_renderDeferred.state() == 'pending'
      return @_renderDeferred
    
    @_renderDeferred = new $.Deferred()
    
    @_getTemplate().done =>
      $("##{@id}").html @_template()
      
      @_processPartials()
      @_parsePartials()
      
      _.each @options.partials, (partial, name) =>
        @getView(name).render() if @getView(name)
          
    @_renderDeferred

  ##### addView( *view* )
  #
  #---
  # Добавляет вью в список
  addView: (view) ->
    
    throw new Inn.Error('view shold be an instance of Inn.View') unless view instanceof Inn.View
    
    viewInLayout = _.find @_views, (existingView)-> existingView.id == view.id
    # _.indexOf(@_views, view) == -1
    @_views.push(view) unless view in @_views or viewInLayout
    
    view.options.layout = @
    
    unless view.model or view.collection
      data = @_dataManager.getDataAsset view.id

      if data
        if data instanceof Inn.Model
          view.model = data
        if data instanceof Inn.Collection
          view.collection = data
      else
        delete view.model
        delete view.collection
    
    # Вешает обработчики на системные события
    view.on 'render', _.bind @_recheckSubViews, this, view
    view.on 'remove', _.bind @_clearSubViews, this, view
    view.on 'remove', _.bind @_onViewRemovedFromDOM, this, view
    
    # Генерирует событие **"add:view"**
    @trigger 'add:view', view
    
    @
    
  ##### getView( *name* )
  #
  #---
  # Возвращает вью с именем **name**
  getView: (name) -> (_.find @_views, (view) -> view.id is name) ? null
        
  ##### removeView( *name* )
  #
  #---
  # Удаляет вью с именем **name**
  removeView: (name) ->
    return null if (survived = _.reject @_views, (view) -> view.id is name).length is @_views.length
    
    @_views = survived
    
    # Генерирует событие **"remove:view"**
    @trigger('remove:view')
  
  ##### _processPartials( *partials* )
  #
  #---
  # Обрабатывает partials и превращает их во вью
  _processPartials: (partials)->
    partials = @options.partials unless partials
    
    for name, partial of partials
      @addView new Inn.View id: name

      view = @getView(name)
      view.options._viewBranch = partial
      view.options.templateName = partial.templateName if partial.templateName
      view.options.templateURL = partial.templateURL if partial.templateURL
      view.options.templateFolder = @options.templateFolder if @options and @options.templateFolder
      view.options.templateFormat = @options.templateFormat if @options and @options.templateFormat
      
      view.attributes = partial.attributes

      @_processPartials(partial.partials) if partial.partials
      
    @
    
  ##### Генерирует( *partialContent* )
  #
  #---
  # Генерирует список partial-ов текущего layout-а
  _parsePartials: (partialContent)->
    layout = this
    
    partialContent = $("##{@id}") unless partialContent
    partialId = partialContent.attr('id')
    
    partialsObject = partials: {}
      
    for element, idx in $(partialContent).children(".#{@options.placeholderClassName}")
      partialsObject.partials[$(element).attr('id')] = {}

    unless @options.partials?
      @_processPartials partialsObject.partials
      @getView(partialId).options._viewBranch = partialsObject if @getView(partialId)

      for name, partial of partialsObject.partials
        @getView(name).render() if @getView(name)
      
  ##### _recheckSubViews( *view* )
  #
  #---
  # 
  _recheckSubViews: (view)->
    @_viewsUnrendered--
    
    if view.el.parentNode is null and $("##{view.id}").length
      $("##{view.id}").replaceWith view.$el
      view.options.isInDOM = on
    
    @_parsePartials view.$el unless view.options._viewBranch.partials
    
    if view.options._viewBranch.partials
      for name, partial of view.options._viewBranch.partials
        @getView(name).render()

    if @_viewsUnrendered <= 0
      @_renderDeferred.resolve()

    @

  ##### _clearSubViews( *view* )
  #
  #---
  # Вызывает метод .remove() у дочерних вью
  _clearSubViews: (view)->
    @_destroyDeferred.notify() if @_destroyDeferred
    
    if view.options._viewBranch.partials
      for name, partial of view.options._viewBranch.partials
        @getView(name).remove() if @getView(name)

  ##### _onViewRemovedFromDOM( *view* )
  #
  #---
  # Обработчик события удаления вью
  _onViewRemovedFromDOM: (view) ->

  ##### destroy()
  #
  #---
  # Уничтожает layout
  destroy: ->
    $("##{@id}").empty()
    
    layout = @
    
    @_destroyDeferred = new $.Deferred()

    @_destroyDeferred.progress ->

      viewsInDOM = _.filter layout._views, (view)-> view.options.isInDOM
      
      @resolve() if viewsInDOM.length == 0

    @_destroyDeferred.done =>
      @removeView(view.id) for view in layout._views

    for name, partial of @options.partials
      @getView(name).remove() if @getView(name)
    
    @_destroyDeferred

##### @defaults
#
#---
# Опции layout-а по умолчанию
Inn.Layout.defaults = 
  placeholderClassName: 'layoutPlaceholder'
  templateFolder: ''
  templateFormat: 'js'