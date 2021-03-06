View = require 'views/kinds/CocoView'
template = require 'templates/play/level/tome/spell_palette'
{me} = require 'lib/auth'
filters = require 'lib/image_filter'
SpellPaletteEntryView = require './spell_palette_entry_view'
LevelComponent = require 'models/LevelComponent'

N_ROWS = 4

module.exports = class SpellPaletteView extends View
  id: 'spell-palette-view'
  template: template
  controlsEnabled: true

  subscriptions:
    'level-disable-controls': 'onDisableControls'
    'level-enable-controls': 'onEnableControls'
    'surface:frame-changed': "onFrameChanged"

  constructor: (options) ->
    super options
    @thang = options.thang
    @createPalette()

  getRenderData: ->
    c = super()
    c.entryGroups = @entryGroups
    c.entryGroupSlugs = @entryGroupSlugs
    c.tabbed = _.size(@entryGroups) > 1
    c

  afterRender: ->
    super()
    for group, entries of @entryGroups
      groupSlug = @entryGroupSlugs[group]
      for columnNumber, entryColumn of entries
        col = $('<div class="property-entry-column"></div>').appendTo @$el.find(".properties-#{groupSlug}")
        for entry in entryColumn
          col.append entry.el
          entry.render()  # Render after appending so that we can access parent container for popover

  createPalette: ->
    lcs = @supermodel.getModels LevelComponent
    allDocs = {}
    for lc in lcs
      for doc in (lc.get('propertyDocumentation') ? [])
        allDocs[doc.name] ?= []
        allDocs[doc.name].push doc
    #allDocs[doc.name] = doc for doc in (lc.get('propertyDocumentation') ? []) for lc in lcs

    props = _.sortBy @thang.programmableProperties ? []
    snippets = _.sortBy @thang.programmableSnippets ? []
    shortenize = props.length + snippets.length > 6
    tabbify = props.length + snippets.length >= 10
    @entries = []
    for type, props of {props: props.slice(), snippets: snippets.slice()}
      for prop in props
        doc = allDocs[prop]?.shift() ? prop  # Add one doc per instance of the prop name (this is super gimp)
        @entries.push @addEntry(doc, shortenize, tabbify, type is 'snippets')
    @entries = _.sortBy @entries, (entry) ->
      order = ['this', 'Math', 'Vector', 'snippets']
      index = order.indexOf entry.doc.owner
      index = String.fromCharCode if index is -1 then order.length else index
      index += entry.doc.name
    if tabbify and _.find @entries, ((entry) -> entry.doc.owner isnt 'this')
      @entryGroups = _.groupBy @entries, (entry) -> entry.doc.owner
    else
      defaultGroup = $.i18n.t("play_level.tome_available_spells", defaultValue: "Available Spells")
      @entryGroups = {}
      @entryGroups[defaultGroup] = @entries
    @entryGroupSlugs = {}
    for group, entries of @entryGroups
      @entryGroupSlugs[group] = _.string.slugify group
      @entryGroups[group] = _.groupBy entries, (entry, i) -> Math.floor i / N_ROWS
    null

  addEntry: (doc, shortenize, tabbify, isSnippet=false) ->
    new SpellPaletteEntryView doc: doc, thang: @thang, shortenize: shortenize, tabbify: tabbify, isSnippet: isSnippet

  onDisableControls: (e) -> @toggleControls e, false
  onEnableControls: (e) -> @toggleControls e, true
  toggleControls: (e, enabled) ->
    return if e.controls and not ('palette' in e.controls)
    return if enabled is @controlsEnabled
    @controlsEnabled = enabled
    @$el.find('*').attr('disabled', not enabled)
    @toggleBackground()

  toggleBackground: =>
    # TODO: make the palette background an actual background and do the CSS trick
    # used in spell_list_entry.sass for disabling
    background = @$el.find('.code-palette-background')[0]
    if background.naturalWidth is 0  # not loaded yet
      return _.delay @toggleBackground, 100
    filters.revertImage background if @controlsEnabled
    filters.darkenImage background, 0.8 unless @controlsEnabled

  onFrameChanged: (e) ->
    return unless e.selectedThang?.id is @thang.id
    @options.thang = @thang = e.selectedThang  # Update our thang to the current version

  destroy: ->
    entry.destroy() for entry in @entries
    @toggleBackground = null
    super()
