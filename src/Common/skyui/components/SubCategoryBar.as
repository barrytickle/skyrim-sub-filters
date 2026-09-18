/**
 * A horizontal row of text sub-category tabs, drawn under the main category
 * icon row. Built entirely at runtime with createEmptyMovieClip and
 * createTextField, so it needs no library symbol and no display-object surgery
 * in the SWF XML. SkyUI does the same in ActiveEffect and WidgetLoader.
 *
 * Owner calls setCategories() with an array of {id, label}, then listens for
 * "categoryPress" and reads event.id.
 *
 * ffdec AS2 constraints apply: no imports, no return types, no switch on
 * static properties, fully qualified self-references.
 */
class skyui.components.SubCategoryBar
{
	var _container;
	var _entries;
	var _tabs;
	var _activeIndex;
	var _barWidth;
	var _owner;
	var _fontSize;
	var dispatchEvent;
	var addEventListener;

	static var PAD_X = 14;
	static var FONT_SIZE = 16;
	static var MIN_PAD = 3;
	static var MIN_FONT = 10;
	static var DIV_ALPHA = 28;
	static var DIV_INSET = 5;
	static var HEIGHT = 22;
	static var ALPHA_ACTIVE = 100;
	static var ALPHA_IDLE = 45;
	static var ALPHA_HOVER = 75;

	function SubCategoryBar(a_parent, a_name, a_depth, a_width)
	{
		gfx.events.EventDispatcher.initialize(this);
		this._entries = [];
		this._tabs = [];
		this._activeIndex = 0;
		this._barWidth = a_width;
		this._fontSize = skyui.components.SubCategoryBar.FONT_SIZE;
		this._container = a_parent.createEmptyMovieClip(a_name, a_depth);
	}

	function get container()
	{
		return this._container;
	}

	function get activeId()
	{
		if (this._entries[this._activeIndex] == undefined)
			return 0;
		return this._entries[this._activeIndex].id;
	}

	function setVisible(a_visible)
	{
		this._container._visible = a_visible;
	}

	function get visible()
	{
		return this._container._visible;
	}

	function setPosition(a_x, a_y)
	{
		this._container._x = a_x;
		this._container._y = a_y;
	}

	function setFontSize(a_size)
	{
		this._fontSize = a_size;
		this.layout();
	}

	function setWidth(a_width)
	{
		this._barWidth = a_width;
		this.layout();
	}

	/** a_entries: array of {id:Number, label:String} */
	function setCategories(a_entries)
	{
		var i = 0;
		while (i < this._tabs.length) {
			this._tabs[i].removeMovieClip();
			i = i + 1;
		}
		this._tabs = [];
		this._entries = a_entries == undefined ? [] : a_entries;
		this._activeIndex = 0;

		var fmt = new TextFormat();
		fmt.font = "$EverywhereMediumFont";
		fmt.size = this._fontSize;
		fmt.color = 0xFFFFFF;
		fmt.align = "center";

		i = 0;
		while (i < this._entries.length) {
			var tab = this._container.createEmptyMovieClip("tab" + i, i + 1);
			tab.createTextField("label", 1, 0, 0, 10, skyui.components.SubCategoryBar.HEIGHT);
			var tf = tab.label;
			tf.selectable = false;
			tf.autoSize = "center";
			tf.embedFonts = false;
			tf.text = this._entries[i].label;
			tf.setTextFormat(fmt);
			tab.tabIndex = i;
			tab.owner = this;
			tab.onRelease = function()
			{
				this.owner.onTabRelease(this.tabIndex);
			};
			tab.onRollOver = function()
			{
				this.owner.onTabRollOver(this.tabIndex);
			};
			tab.onRollOut = function()
			{
				this.owner.onTabRollOut(this.tabIndex);
			};
			this._tabs.push(tab);
			i = i + 1;
		}
		this.layout();
	}

	/**
	 * Variable-width distribution. Stock CategoryList assumes fixed-width icons
	 * and divides the leftover evenly; text labels must be measured first.
	 */
	/** Apply a font size to every label and return the total width needed. */
	function measureAt(a_size, a_pad)
	{
		var fmt = new TextFormat();
		fmt.font = "$EverywhereMediumFont";
		fmt.size = a_size;
		fmt.color = 0xFFFFFF;
		fmt.align = "center";
		var t = 0;
		var i = 0;
		while (i < this._tabs.length) {
			this._tabs[i].label.setTextFormat(fmt);
			t = t + this._tabs[i].label._width + (a_pad * 2);
			i = i + 1;
		}
		return t;
	}

	/**
	 * Variable-width distribution with auto-fit. Stock CategoryList assumes
	 * fixed-width icons; text labels must be measured.
	 *
	 * A Flash MovieClip does NOT clip its children, so an overflowing row would
	 * draw straight over the item preview rather than being hidden or scrolled.
	 * The brief's decision was "fit, do not scroll", so when the labels do not
	 * fit we shrink padding first, then font size, before giving up.
	 */
	function layout()
	{
		var n = this._tabs.length;
		if (n == 0)
			return;

		var size = this._fontSize;
		var pad = skyui.components.SubCategoryBar.PAD_X;
		var total = this.measureAt(size, pad);

		var guard = 0;
		while (total > this._barWidth && guard < 24) {
			if (pad > skyui.components.SubCategoryBar.MIN_PAD) {
				pad = pad - 1;
			} else if (size > skyui.components.SubCategoryBar.MIN_FONT) {
				size = size - 1;
			} else {
				break;
			}
			total = this.measureAt(size, pad);
			guard = guard + 1;
		}

		var gap = 0;
		if (this._barWidth > total)
			gap = (this._barWidth - total) / (n + 1);

		// dividers are drawn on the container, not the tabs, so they keep a
		// constant alpha while tabs brighten and dim
		this._container.clear();
		this._container.lineStyle(1, 0xFFFFFF, skyui.components.SubCategoryBar.DIV_ALPHA);

		var x = gap;
		var i = 0;
		while (i < n) {
			var tab = this._tabs[i];
			var w = tab.label._width + (pad * 2);
			if (i > 0) {
				var dx = Math.round(x - (gap / 2));
				this._container.moveTo(dx, skyui.components.SubCategoryBar.DIV_INSET);
				this._container.lineTo(dx, skyui.components.SubCategoryBar.HEIGHT - skyui.components.SubCategoryBar.DIV_INSET);
			}
			tab.label._x = pad;
			tab.label._y = 0;
			tab._x = x;
			tab._y = 0;
			tab.clear();
			tab.beginFill(0x000000, 0);
			tab.moveTo(0, 0);
			tab.lineTo(w, 0);
			tab.lineTo(w, skyui.components.SubCategoryBar.HEIGHT);
			tab.lineTo(0, skyui.components.SubCategoryBar.HEIGHT);
			tab.endFill();
			x = x + w + gap;
			i = i + 1;
		}
		this.refreshState();
	}

	/** Re-derive every tab's alpha from state. Never hardcode on roll-out. */
	function refreshState()
	{
		var i = 0;
		while (i < this._tabs.length) {
			this._tabs[i]._alpha = i == this._activeIndex
				? skyui.components.SubCategoryBar.ALPHA_ACTIVE
				: skyui.components.SubCategoryBar.ALPHA_IDLE;
			i = i + 1;
		}
	}

	function setActiveIndex(a_index)
	{
		if (a_index < 0 || a_index >= this._entries.length)
			return;
		this._activeIndex = a_index;
		this.refreshState();
	}

	function onTabRelease(a_index)
	{
		if (a_index == this._activeIndex)
			return;
		this._activeIndex = a_index;
		this.refreshState();
		this.dispatchEvent({type: "categoryPress", id: this._entries[a_index].id, index: a_index});
	}

	function onTabRollOver(a_index)
	{
		if (a_index == this._activeIndex)
			return;
		this._tabs[a_index]._alpha = skyui.components.SubCategoryBar.ALPHA_HOVER;
	}

	function onTabRollOut(a_index)
	{
		// re-derive rather than restore a hardcoded value, which is the latent
		// bug in stock CategoryList.onItemRollOut
		this.refreshState();
	}
}
