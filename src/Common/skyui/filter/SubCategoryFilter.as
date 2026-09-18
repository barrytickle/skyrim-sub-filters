/**
 * Filters the item list down to a sub-category within the active top-level
 * category, e.g. only Crossbows while the Weapons tab is selected.
 *
 * Matching uses the NON-LOCALISED numeric fields on the entry object, verified
 * in game 2026-09-18: a Steel Crossbow reports weaponType 9 / subType 9 /
 * formType 41, an Iron Sword reports 1 / 1 / 41.
 *
 * STYLE CONSTRAINTS, learned the hard way with ffdec's AS2 parser:
 *   - no "import" statements, use fully qualified names
 *   - no return type annotations on functions
 *   - no switch with static-property case labels, and no private static vars
 *     read from static methods; both compiled silently but matched nothing at
 *     runtime. Plain numeric literals in if/else are used instead, with the
 *     constant names kept in comments.
 */
class skyui.filter.SubCategoryFilter implements skyui.filter.IFilter
{
	public static var CAT_ALL = 0;
	public static var CAT_SWORDS = 1;
	public static var CAT_AXES = 2;
	public static var CAT_BOWS = 3;
	public static var CAT_CROSSBOWS = 4;
	public static var CAT_DAGGERS = 5;
	public static var CAT_AMMO = 6;
	public static var CAT_MACES = 7;
	public static var CAT_STAVES = 8;
	public static var CAT_CLOTHES = 20;
	public static var CAT_LIGHTARMOR = 21;
	public static var CAT_HEAVYARMOR = 22;
	public static var CAT_ROBES = 23;
	public static var CAT_SHIELDS = 24;
	public static var CAT_JEWELLERY = 25;

	var _category;
	var dispatchEvent;
	var addEventListener;

	function SubCategoryFilter()
	{
		gfx.events.EventDispatcher.initialize(this);
		this._category = 0;
	}

	function get category()
	{
		return this._category;
	}

	function changeCategory(a_category, a_bDoNotUpdate)
	{
		if (a_bDoNotUpdate == undefined)
			a_bDoNotUpdate = false;
		if (a_category == undefined)
			a_category = 0;
		if (a_category == this._category)
			return;
		this._category = a_category;
		if (!a_bDoNotUpdate)
			this.dispatchEvent({type: "filterChange"});
	}

	function applyFilter(a_filteredList)
	{
		if (this._category == 0)
			return;
		var i = 0;
		while (i < a_filteredList.length) {
			if (!skyui.filter.SubCategoryFilter.entryMatches(a_filteredList[i], this._category)) {
				a_filteredList.splice(i, 1);
			} else {
				i = i + 1;
			}
		}
	}

	function isMatch(a_entry, a_category)
	{
		return skyui.filter.SubCategoryFilter.entryMatches(a_entry, a_category);
	}

	static function isWarhammer(a_entry)
	{
		return a_entry.keywords != undefined
			&& a_entry.keywords.WeapTypeWarhammer != undefined;
	}

	static function isRobe(a_entry)
	{
		if (a_entry.keywords == undefined)
			return false;
		if (a_entry.keywords.OCF_varNotRobes != undefined)
			return false;
		return a_entry.keywords.OCF_BodyTypeRobes != undefined
			|| a_entry.keywords.OCF_BodyTypeRobes_Generic != undefined
			|| a_entry.keywords.OCF_BodyTypeRobes_Mage != undefined;
	}

	static function entryMatches(a_entry, a_category)
	{
		if (a_entry == undefined)
			return false;
		if (a_category == 0)
			return true;

		var wt = a_entry.weaponType;
		var wc = a_entry.weightClass;
		var pm = a_entry.partMask;

		// weaponType holds ANIM_* values, NOT TYPE_*. Confirmed in game 2026-09-18.
		// Skyrim uses two parallel ANIM ranges (0-9 and 10-19) for the same
		// weapon classes, exactly as processWeaponType switches on both.
		//   0/10 handtohand  1/11 sword   2/12 dagger  3/13 waraxe  4/14 mace
		//   5/15 greatsword  6/16 2H axe  7/17 bow     8/18 staff   9/19 crossbow
		// Battleaxe and warhammer BOTH report 6, so they are separated by the
		// WeapTypeWarhammer keyword, the same way SkyUI does it.
		if (a_category == 1)
			return wt == 1 || wt == 11 || wt == 5 || wt == 15;
		if (a_category == 2)
			return wt == 3 || wt == 13
				|| ((wt == 6 || wt == 16) && !skyui.filter.SubCategoryFilter.isWarhammer(a_entry));
		if (a_category == 3)
			return wt == 7 || wt == 17;
		if (a_category == 4)
			return wt == 9 || wt == 19;
		if (a_category == 5)
			return wt == 2 || wt == 12;
		if (a_category == 6)
			return a_entry.formType == 42;
		if (a_category == 7)
			return wt == 4 || wt == 14
				|| ((wt == 6 || wt == 16) && skyui.filter.SubCategoryFilter.isWarhammer(a_entry));
		if (a_category == 8)
			return wt == 8 || wt == 18;

		// Apparel values MEASURED in game 2026-09-18, not assumed:
		//   Light 0, Heavy 1, Clothing 3, Jewellery 4, and null for oddities
		//   like the Leather Bandolier (slot 53, shown as "Other").
		//   weightClass here is ALREADY PROCESSED, unlike weapon subType.
		// Shields carry a real weight class too (Falmer A0/512, Imperial
		// A1/512), so they must be excluded from LIGHT and HEAVY or they would
		// appear under two tabs.
		var isShield = pm != undefined && (pm & 512) != 0;

		if (a_category == 24)
			return isShield;
		if (a_category == 23)
			return skyui.filter.SubCategoryFilter.isRobe(a_entry);
		if (a_category == 20)
			return wc == 3 && !skyui.filter.SubCategoryFilter.isRobe(a_entry);
		if (a_category == 21)
			return wc == 0 && !isShield;
		if (a_category == 22)
			return wc == 1 && !isShield;
		if (a_category == 25)
			return wc == 4;

		return true;
	}
}
