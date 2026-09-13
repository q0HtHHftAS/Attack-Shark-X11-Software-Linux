<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { Plus, Trash2, ChevronDown } from 'lucide-vue-next';
import BaseButton from './BaseButton.vue';
import BaseInput from './BaseInput.vue';
import BaseSelect from './BaseSelect.vue';
import BaseSlider from './BaseSlider.vue';
import BaseToggle from './BaseToggle.vue';
import StatusMessage from './StatusMessage.vue';
import CustomMacroModal from './CustomMacroModal.vue';
import { macroTemplates, MacroName, type MacroTuple } from '../../../shared/macro-templates.js';
import mouseImg from '../assets/mouse-x11.png';

const props = defineProps<{
	isConnected: boolean;
	deviceModel: 'X11' | 'X11SE' | 'R1';
	connectionMode: 'Adapter' | 'Wired' | null;
	batteryLevel: number;
}>();

const { t } = useI18n();

const isWired = computed(() => props.connectionMode === 'Wired');
const isR1 = computed(() => props.deviceModel === 'R1');

// ---------------------------------------------------------------- mouse dots
// Numbered like the vendor driver: 1 left, 2 right, 3 middle, 4 forward, 5 back
const DOTS = [
	{ n: 1, button: 0, x: 39, y: 31 },
	{ n: 2, button: 1, x: 61, y: 31 },
	{ n: 3, button: 2, x: 50, y: 23 },
	{ n: 4, button: 3, x: 29, y: 41 },
	{ n: 5, button: 4, x: 29, y: 50 },
];

const buttonNames = computed(() => [
	t('macros.buttons.left'),
	t('macros.buttons.right'),
	t('macros.buttons.middle'),
	t('macros.buttons.forward'),
	t('macros.buttons.backward'),
]);

// ---------------------------------------------------------------- state
const R1_DPI = [800, 1600, 3200, 4000, 5000, 12000] as [number, number, number, number, number, number];
const X11_DPI = [800, 1600, 2400, 3200, 5000, 22000] as [number, number, number, number, number, number];

const dpi = reactive({
	activeStage: 2,
	angleSnap: false,
	ripplerControl: true,
	dpiValues: (props.deviceModel === 'R1' ? R1_DPI : X11_DPI).slice() as [
		number,
		number,
		number,
		number,
		number,
		number,
	],
});

const prefs = reactive({
	lightMode: 0x20,
	ledSpeed: 2,
	keyResponse: 4,
	pollingRate: 1000,
	sleepTime: 2,
	deepSleepTime: 10,
	rgb: { r: 255, g: 0, b: 255 },
});

const dpiMin = computed(() => (props.deviceModel === 'R1' ? 100 : 50));
const dpiMax = computed(() => (props.deviceModel === 'R1' ? 18000 : 22000));
const dpiStep = computed(() => (props.deviceModel === 'R1' ? 100 : 50));

// Orange fill up to the thumb (Chromium has no native fill for range inputs)
const dpiFill = (i: number): string => {
	const min = dpiMin.value;
	const max = dpiMax.value;
	const v = Math.max(min, Math.min(max, dpi.dpiValues[i - 1] ?? min));
	const p = ((v - min) / (max - min)) * 100;
	return `background: linear-gradient(to top, #E95420 ${p}%, var(--bg-primary) ${p}%)`;
};

// Click a value to type it in directly (easier than dragging to an exact DPI)
const editingStage = ref<number | null>(null);

// ---------------------------------------------------------------- left column
const selectedButton = ref(0);
const openMenu = ref<number | null>(null);
const menuAnchor = ref({ top: 0, left: 0, width: 240 });
const subAnchor = ref({ top: 0 });
const menuButton = computed(() => openMenu.value ?? 0);
const openSub = ref<string | null>(null);
const leftStatus = ref('');
const leftError = ref(false);
const applyingMap = ref(false);

// Current mapping per physical button (index 0-5)
const assignments = ref<Record<number, MacroName>>({
	0: MacroName.GLOBAL_LEFT_CLICK,
	1: MacroName.GLOBAL_RIGHT_CLICK,
	2: MacroName.GLOBAL_MIDDLE,
	3: MacroName.GLOBAL_FORWARD,
	4: MacroName.GLOBAL_BACKWARD,
	5: MacroName.GLOBAL_DPI_CYCLE,
});

interface RemapGroup {
	key: string;
	labelKey: string | null;
	items: MacroName[];
}
const REMAP_MENU: RemapGroup[] = [
	{
		key: 'clicks',
		labelKey: null,
		items: [
			MacroName.GLOBAL_LEFT_CLICK,
			MacroName.GLOBAL_RIGHT_CLICK,
			MacroName.GLOBAL_MIDDLE,
			MacroName.GLOBAL_FORWARD,
			MacroName.GLOBAL_BACKWARD,
		],
	},
	{
		key: 'actions',
		labelKey: null,
		items: [MacroName.GLOBAL_DOUBLE_CLICK, MacroName.GLOBAL_FIRE_BUTTON, MacroName.GLOBAL_EASY_AIM],
	},
	{
		key: 'scroll',
		labelKey: null,
		items: [MacroName.GLOBAL_SCROLL_UP, MacroName.GLOBAL_SCROLL_DOWN, MacroName.GLOBAL_DISABLE_BUTTON],
	},
	{
		key: 'dpi',
		labelKey: 'remap.groups.dpi',
		items: [MacroName.GLOBAL_DPI_CYCLE, MacroName.GLOBAL_DPI_PLUS, MacroName.GLOBAL_DPI_MINUS],
	},
	{
		key: 'multimedia',
		labelKey: 'remap.groups.multimedia',
		items: [
			MacroName.MULTIMEDIA_MEDIA_PLAYER,
			MacroName.MULTIMEDIA_PLAY_PAUSE,
			MacroName.MULTIMEDIA_STOP_MUSIC,
			MacroName.MULTIMEDIA_PREVIOUS_TRACK,
			MacroName.MULTIMEDIA_NEXT_TRACK,
			MacroName.MULTIMEDIA_VOLUME_PLUS,
			MacroName.MULTIMEDIA_VOLUME_MINUS,
			MacroName.MULTIMEDIA_MUTE,
		],
	},
	{
		key: 'browser',
		labelKey: 'remap.groups.browser',
		items: [
			MacroName.BROWSER_HOME,
			MacroName.BROWSER_FAVORITES,
			MacroName.BROWSER_FORWARD,
			MacroName.BROWSER_BACKWARD,
			MacroName.BROWSER_STOP,
			MacroName.BROWSER_REFRESH,
			MacroName.BROWSER_SEARCH,
			MacroName.BROWSER_EMAIL,
			MacroName.BROWSER_CALCULATOR,
			MacroName.BROWSER_MY_COMPUTER,
		],
	},
	{
		key: 'shortcut',
		labelKey: 'remap.groups.shortcut',
		items: [
			MacroName.SHORTCUT_CUT,
			MacroName.SHORTCUT_COPY,
			MacroName.SHORTCUT_PASTE,
			MacroName.SHORTCUT_OPEN,
			MacroName.SHORTCUT_SAVE,
			MacroName.SHORTCUT_FIND,
			MacroName.SHORTCUT_REDO,
			MacroName.SHORTCUT_SELECT_ALL,
			MacroName.SHORTCUT_PRINT,
			MacroName.SHORTCUT_CLOSE_WINDOW,
			MacroName.SHORTCUT_SWAP_WINDOW,
			MacroName.SHORTCUT_SHOW_DESKTOP,
			MacroName.SHORTCUT_RUN_COMMAND,
			MacroName.SHORTCUT_LOCK_PC,
			MacroName.SHORTCUT_SCREEN_CAPTURE,
		],
	},
];

const toggleMenu = (index: number, ev?: MouseEvent) => {
	selectedButton.value = index;
	openSub.value = null;
	if (openMenu.value === index) {
		openMenu.value = null;
		return;
	}
	// Float the menu (fixed position) so it escapes the panel like the vendor UI.
	// Flip upward when it would overflow the bottom edge.
	const target = (ev?.currentTarget ?? null) as HTMLElement | null;
	const rect = target?.getBoundingClientRect();
	if (rect) {
		// +44 for the single-line header (button name), otherwise lower rows get cut at the bottom edge.
		const estH = REMAP_MENU.reduce((n, g) => n + (g.labelKey ? 1 : g.items.length), 0) * 32 + 8 + 44;
		const width = Math.max(rect.width, 240);
		// Open beside the pressed row (right side), top-aligned; clamp into view.
		const top = Math.max(8, Math.min(rect.top, window.innerHeight - estH - 8));
		menuAnchor.value = { top, left: rect.right + 6, width };
	}
	openMenu.value = index;
};

const toggleSub = (key: string, ev?: MouseEvent) => {
	if (openSub.value === key) {
		openSub.value = null;
		return;
	}
	const target = (ev?.currentTarget ?? null) as HTMLElement | null;
	const rect = target?.getBoundingClientRect();
	const group = REMAP_MENU.find((g) => g.key === key);
	const estH = (group?.items.length ?? 5) * 32 + 8;
	let top = rect ? rect.top - 4 : 200;
	if (top + estH > window.innerHeight) top = Math.max(8, window.innerHeight - estH - 8);
	subAnchor.value = { top };
	openSub.value = key;
};

const closeMenu = () => {
	openMenu.value = null;
	openSub.value = null;
};

const remapLabel = (name: MacroName): string =>
	name.startsWith('custom-macro') ? t('macromodal.title') : t(`remap.${name}`);

// Full button state → one 0x0308 report. Never send a single button alone:
// the firmware replaces the whole mapping, so a lone write wipes the others.
const BUTTON_KEYS = ['left', 'right', 'middle', 'forward', 'backward', 'dpi'];
const buildMacroConfig = (state: Record<number, MacroName>, except?: number): Record<string, MacroTuple> => {
	const macroConfig: Record<string, MacroTuple> = {};
	for (const [btn, macro] of Object.entries(state)) {
		if (Number(btn) === except) continue;
		const key = BUTTON_KEYS[Number(btn)];
		const tuple = macroTemplates[macro];
		if (key && tuple) macroConfig[key] = tuple;
	}
	return macroConfig;
};

const CUSTOM_TEMPLATES: Record<number, MacroName> = {
	0: MacroName.CUSTOM_MACRO_LEFT_BUTTON,
	1: MacroName.CUSTOM_MACRO_RIGHT_BUTTON,
	2: MacroName.CUSTOM_MACRO_MIDDLE_BUTTON,
	3: MacroName.CUSTOM_MACRO_EXTRA_BUTTON_4,
	4: MacroName.CUSTOM_MACRO_EXTRA_BUTTON_5,
};

const applyMapping = async (buttonIndex: number, name: MacroName) => {
	if (!props.isConnected || applyingMap.value) return;
	applyingMap.value = true;
	leftError.value = false;
	leftStatus.value = t('macros.applying');
	try {
		const next = { ...assignments.value, [buttonIndex]: name };
		await window.api.setMacro(buildMacroConfig(next));
		assignments.value = next;
		openMenu.value = null;
		openSub.value = null;
		leftStatus.value = t('macros.macroAssigned');
		setTimeout(() => (leftStatus.value = ''), 3000);
		void persistSettings();
	} catch (err: unknown) {
		leftError.value = true;
		leftStatus.value = `${t('macros.errorPrefix')}${err instanceof Error ? err.message : String(err)}`;
	} finally {
		applyingMap.value = false;
	}
};

// A custom macro binds its target via its own 0x0308 def packet (wiping the
// rest to defaults), so re-apply every other button right after.
const onCustomMacroApplied = async (button: number) => {
	const template = CUSTOM_TEMPLATES[button];
	if (template) assignments.value = { ...assignments.value, [button]: template };
	try {
		await window.api.setMacro(buildMacroConfig(assignments.value, button));
		void persistSettings();
	} catch (err: unknown) {
		leftError.value = true;
		leftStatus.value = `${t('macros.errorPrefix')}${err instanceof Error ? err.message : String(err)}`;
	}
};

// ---------------------------------------------------------------- profiles
const profiles = ref<string[]>([]);
const newProfileName = ref('');

const loadProfiles = async () => {
	profiles.value = (await window.api.listProfiles()).filter((n) => !n.startsWith('__macro__'));
};

const saveProfile = async () => {
	if (!newProfileName.value) return;
	await window.api.saveProfile(newProfileName.value, {
		prefs: JSON.parse(JSON.stringify(prefs)),
		dpi: JSON.parse(JSON.stringify(dpi)),
		mappings: { ...assignments.value },
	});
	newProfileName.value = '';
	await loadProfiles();
};

const applyProfile = async (name: string) => {
	if (!props.isConnected) return;
	leftError.value = false;
	try {
		const data = (await window.api.loadProfile(name)) as {
			prefs?: typeof prefs;
			dpi?: typeof dpi;
			mappings?: Record<number, MacroName>;
		} | null;
		if (!data) return;
		if (data.prefs) {
			Object.assign(prefs, data.prefs);
			await applyPrefs();
		}
		if (data.dpi) {
			Object.assign(dpi, data.dpi);
			await applyDpi(false);
		}
		// One combined 0x0308 transfer for all mappings (not one per button)
		if (data.mappings) {
			const merged = { ...assignments.value, ...data.mappings };
			const macroConfig = buildMacroConfig(merged);
			if (Object.keys(macroConfig).length > 0) {
				await window.api.setMacro(macroConfig);
				assignments.value = merged;
				void persistSettings();
			}
		}
	} catch (err: unknown) {
		leftError.value = true;
		leftStatus.value = `${t('macros.errorPrefix')}${err instanceof Error ? err.message : String(err)}`;
	}
};

const deleteProfile = async (name: string) => {
	await window.api.deleteProfile(name);
	await loadProfiles();
};

const showMacroModal = ref(false);

// ---------------------------------------------------------------- right column
const rightStatus = ref('');
const rightError = ref(false);
const applyingDpi = ref(false);

const applyDpi = async (showUi = true) => {
	if (!props.isConnected) return;
	if (showUi) {
		applyingDpi.value = true;
		rightError.value = false;
		rightStatus.value = t('dpi.updating');
	}
	try {
		await window.api.setDpi({
			activeStage: dpi.activeStage,
			angleSnap: dpi.angleSnap,
			ripplerControl: dpi.ripplerControl,
			dpiValues: [...dpi.dpiValues],
		});
		if (showUi) {
			rightStatus.value = t('dpi.applied');
			setTimeout(() => (rightStatus.value = ''), 3000);
		}
	} catch (err: unknown) {
		rightError.value = true;
		rightStatus.value = `${t('dpi.error')}: ${err instanceof Error ? err.message : String(err)}`;
	} finally {
		if (showUi) applyingDpi.value = false;
	}
};

let prefsTimer: ReturnType<typeof setTimeout>;
const applyPrefs = async (showUi = true) => {
	if (!props.isConnected) return;
	if (showUi) {
		rightError.value = false;
		rightStatus.value = t('preferences.applyingSettings');
	}
	try {
		const payload = isWired.value
			? { keyResponse: prefs.keyResponse, sleepTime: prefs.sleepTime, deepSleepTime: prefs.deepSleepTime }
			: {
					lightMode: prefs.lightMode,
					ledSpeed: prefs.ledSpeed,
					keyResponse: prefs.keyResponse,
					sleepTime: prefs.sleepTime,
					deepSleepTime: prefs.deepSleepTime,
					rgb: { ...prefs.rgb },
				};
		await window.api.setUserPreferences(payload);
		await window.api.setPollingRate(prefs.pollingRate);
		if (showUi) {
			rightStatus.value = t('preferences.settingsApplied');
			setTimeout(() => (rightStatus.value = ''), 3000);
		}
	} catch (err: unknown) {
		rightError.value = true;
		rightStatus.value = `${t('preferences.errorPrefix')}${err instanceof Error ? err.message : String(err)}`;
	}
};

// Auto-apply pref/dpi-tweak changes (debounced); DPI stages use explicit Apply
watch(
	prefs,
	() => {
		clearTimeout(prefsTimer);
		prefsTimer = setTimeout(() => void applyPrefs(false), 400);
		void persistSettings();
	},
	{ deep: true },
);

watch(
	() => [dpi.angleSnap, dpi.ripplerControl],
	() => {
		void applyDpi(false);
		void persistSettings();
	},
);

const persistSettings = async () => {
	const s = await window.api.getSettings();
	await window.api.saveSettings({
		...s,
		preferences: JSON.parse(JSON.stringify(prefs)),
		dpiConfig: JSON.parse(JSON.stringify(dpi)),
		mappings: { ...assignments.value },
	});
};

// ---------------------------------------------------------------- collapsibles
// Accordion: at most one section open, so the right column never overflows
// the fixed-size window (no scrollbar). Clicking the open section collapses all.
const openSection = ref<string | null>(null);
const toggleSection = (key: string) => {
	openSection.value = openSection.value === key ? null : key;
};

const lightModes = computed(() => [
	{ label: t('preferences.lightModes.off'), value: 0x00 },
	{ label: t('preferences.lightModes.static'), value: 0x10 },
	{ label: t('preferences.lightModes.breathing'), value: 0x20 },
	{ label: t('preferences.lightModes.neon'), value: 0x30 },
	{ label: t('preferences.lightModes.colorBreathing'), value: 0x40 },
	{ label: t('preferences.lightModes.staticDpi'), value: 0x50 },
	{ label: t('preferences.lightModes.breathingDpi'), value: 0x60 },
]);
const pollingOptions = [
	{ label: '125Hz', value: 125 },
	{ label: '250Hz', value: 250 },
	{ label: '500Hz', value: 500 },
	{ label: '1000Hz', value: 1000 },
];
const keyResponses = Array.from({ length: 24 }, (_, i) => 4 + i * 2);
const keyResponseOptions = keyResponses.map((ms) => ({ label: `${ms}ms`, value: ms }));

onMounted(async () => {
	await loadProfiles();
	window.addEventListener('scroll', closeMenu, true);
	try {
		const settings = await window.api.getSettings();
		if (settings?.preferences) Object.assign(prefs, settings.preferences);
		if (settings?.dpiConfig) {
			Object.assign(dpi, settings.dpiConfig);
			const max = props.deviceModel === 'R1' ? 18000 : 22000;
			const min = props.deviceModel === 'R1' ? 100 : 50;
			dpi.dpiValues = dpi.dpiValues.map((v) => Math.max(min, Math.min(max, v))) as typeof dpi.dpiValues;
		}
		if (settings?.mappings) {
			const restored = { ...assignments.value };
			for (const [k, v] of Object.entries(settings.mappings)) {
				const btn = Number(k);
				if (Number.isInteger(btn) && btn >= 0 && btn <= 5 && typeof v === 'string' && v in macroTemplates) {
					restored[btn] = v as MacroName;
				}
			}
			assignments.value = restored;
		}
	} catch {
		// defaults stand
	}
});

onUnmounted(() => {
	window.removeEventListener('scroll', closeMenu, true);
});
</script>

<template>
	<div class="grid grid-cols-1 lg:grid-cols-[260px_minmax(0,1fr)_280px] gap-3 items-start">
		<!-- ================= LEFT ================= -->
		<div class="space-y-3">
			<!-- Button Settings (each row is a remap dropdown, like the vendor driver) -->
			<section class="yaru-enter relative bg-[var(--bg-card)] rounded-2xl border border-[var(--border-card)]">
				<header
					class="px-4 py-2.5 text-sm font-semibold text-[var(--text-secondary)] border-b border-[var(--border-card)]"
				>
					{{ $t('dashboard.buttonSettings') }}
				</header>
				<div class="p-3 space-y-1.5">
					<div v-for="(name, i) in buttonNames" :key="i">
						<button
							@click="toggleMenu(i, $event)"
							:class="[
								'w-full flex items-center gap-2.5 px-3 py-1.5 rounded-lg text-sm transition-all',
								selectedButton === i || openMenu === i
									? 'bg-[#E95420]/15 text-[#f9a88a] shadow-[inset_0_0_0_1px_rgba(233,84,32,0.5)]'
									: 'text-[var(--text-secondary)] hover:bg-[var(--surface-hover)] hover:text-[var(--text-primary)]',
							]"
						>
							<span
								:class="[
									'w-6 h-6 flex items-center justify-center rounded-md text-xs font-bold flex-shrink-0',
									selectedButton === i
										? 'bg-[#E95420] text-white'
										: 'bg-[var(--bg-elevated)] text-[var(--text-muted)]',
								]"
							>
								{{ i + 1 }}
							</span>
							<span class="flex-1 min-w-0 text-left">
								<span class="block truncate">{{ name }}</span>
								<span class="block truncate text-xs opacity-60">{{
									remapLabel(assignments[i] ?? MacroName.GLOBAL_LEFT_CLICK)
								}}</span>
							</span>
							<ChevronDown
								class="w-4 h-4 flex-shrink-0 transition-transform duration-200"
								:class="openMenu === i ? 'rotate-180' : ''"
							/>
						</button>
					</div>
				</div>
			</section>

			<!-- Macro Manager bar -->
			<button
				@click="showMacroModal = true"
				class="yaru-enter yaru-enter-1 w-full py-2 rounded-xl bg-[var(--bg-card)] border border-[var(--border-card)] text-sm font-semibold text-[var(--text-secondary)] hover:text-[#f9a88a] hover:border-[#E95420]/60 transition-all"
			>
				{{ $t('dashboard.macroManager') }}
			</button>

			<CustomMacroModal
				v-if="showMacroModal"
				:isConnected="isConnected"
				:initialButton="selectedButton <= 4 ? selectedButton : 3"
				@close="showMacroModal = false"
				@applied="onCustomMacroApplied"
			/>

			<!-- DPI Settings -->
			<section
				class="yaru-enter yaru-enter-2 bg-[var(--bg-card)] rounded-2xl border border-[var(--border-card)] overflow-hidden"
			>
				<header
					class="px-4 py-2.5 text-sm font-semibold text-[var(--text-secondary)] border-b border-[var(--border-card)]"
				>
					{{ $t('dashboard.dpiSettings') }}
				</header>
				<div class="p-3">
					<div class="flex justify-between gap-1">
						<div
							v-for="i in 6"
							:key="i"
							:class="[
								'flex flex-1 min-w-0 flex-col items-center gap-1.5 rounded-lg py-1.5 transition-colors',
								dpi.activeStage === i ? 'bg-[#E95420]/10' : '',
							]"
						>
							<button
								v-if="editingStage !== i"
								@click="editingStage = i"
								class="w-full truncate text-center text-[10px] font-bold tabular-nums rounded-md px-0.5 py-1 bg-white text-black hover:bg-neutral-200 transition-colors"
								:class="dpi.activeStage === i ? 'outline outline-2 outline-[#E95420]' : ''"
								:title="'Click to type a DPI value'"
							>
								{{ dpi.dpiValues[i - 1] }}
							</button>
							<input
								v-else
								type="number"
								v-model.number="dpi.dpiValues[i - 1]"
								:min="dpiMin"
								:max="dpiMax"
								:step="dpiStep"
								@blur="
									dpi.dpiValues[i - 1] = Math.max(
										dpiMin,
										Math.min(dpiMax, dpi.dpiValues[i - 1] ?? dpiMin),
									);
									editingStage = null;
								"
								@keyup.enter="($event.target as HTMLInputElement).blur()"
								class="w-full text-center text-[10px] font-bold tabular-nums bg-[var(--bg-primary)] border border-[#E95420] rounded-md py-1 text-[var(--text-primary)] focus:outline-none"
							/>
							<div class="h-32 flex items-center justify-center overflow-visible">
								<BaseSlider
									v-model="dpi.dpiValues[i - 1]"
									:min="dpiMin"
									:max="dpiMax"
									:step="dpiStep"
									:style="dpiFill(i)"
									class="dpi-vertical"
									orient="vertical"
								/>
							</div>
							<button
								@click="dpi.activeStage = i as 1 | 2 | 3 | 4 | 5 | 6"
								:class="[
									'w-6 h-6 rounded-full text-[11px] font-bold transition-all',
									dpi.activeStage === i
										? 'bg-[#E95420] text-white'
										: 'bg-[var(--bg-elevated)] text-[var(--text-muted)] hover:text-[var(--text-primary)]',
								]"
							>
								{{ i }}
							</button>
						</div>
					</div>
					<div
						class="flex items-center justify-between px-1.5 pt-2 text-[10px] tabular-nums text-[var(--text-muted)]"
					>
						<span>{{ dpiMin }} – {{ dpiMax }} DPI</span>
						<span>{{ $t('dashboard.activeStage', { stage: dpi.activeStage }) }}</span>
					</div>
					<BaseButton
						@click="applyDpi(true)"
						:disabled="!isConnected || applyingDpi"
						variant="green"
						class="w-full mt-1"
					>
						{{ applyingDpi ? $t('macros.applying') : $t('dashboard.apply') }}
					</BaseButton>
				</div>
			</section>

			<StatusMessage :message="leftStatus" :type="leftError ? 'error' : 'success'" />
		</div>

		<!-- ================= CENTER ================= -->
		<div class="yaru-enter yaru-enter-1 self-stretch flex items-center justify-center py-2">
			<div class="relative w-fit select-none">
				<img
					:src="mouseImg"
					alt="Attack Shark X11"
					class="w-auto"
					style="height: min(680px, calc(100vh - 180px))"
					draggable="false"
				/>
				<button
					v-for="d in DOTS"
					:key="d.n"
					@click="selectedButton = d.button"
					:aria-label="buttonNames[d.button]"
					:title="buttonNames[d.button]"
					class="absolute z-10 -translate-x-1/2 -translate-y-1/2 cursor-pointer"
					:style="{ left: d.x + '%', top: d.y + '%' }"
				>
					<span
						:class="[
							'hotspot-dot block w-6 h-6 rounded-full text-xs font-bold flex items-center justify-center transition-all',
							selectedButton === d.button
								? 'bg-[#E95420] text-white scale-125'
								: 'bg-white text-[#E95420] border-2 border-[#E95420] hover:scale-125',
						]"
					>
						{{ d.n }}
					</span>
				</button>
			</div>
		</div>

		<!-- ================= RIGHT ================= -->
		<div class="space-y-5">
			<!-- Profile -->
			<section
				class="yaru-enter yaru-enter-2 bg-[var(--bg-card)] rounded-2xl border border-[var(--border-card)] overflow-hidden"
			>
				<header
					class="px-4 py-2.5 text-sm font-semibold text-[var(--text-secondary)] border-b border-[var(--border-card)]"
				>
					{{ $t('dashboard.profile') }}
				</header>
				<div class="p-3 space-y-2">
					<button
						v-for="p in profiles"
						:key="p"
						@click="applyProfile(p)"
						class="w-full group flex items-center gap-2 px-3 py-2 rounded-lg text-sm bg-[var(--bg-primary)] border border-[var(--border-card)] hover:border-[#E95420]/60 transition-all"
					>
						<span class="flex-1 truncate text-left text-[var(--text-primary)]">{{ p }}</span>
						<Trash2
							class="w-4 h-4 text-[var(--text-muted)] opacity-0 group-hover:opacity-100 hover:text-red-400 transition-all"
							@click.stop="deleteProfile(p)"
						/>
					</button>
					<p v-if="profiles.length === 0" class="text-xs text-[var(--text-muted)] px-1 py-2 text-center">
						{{ $t('dashboard.noProfiles') }}
					</p>
					<div class="flex gap-2">
						<BaseInput
							v-model="newProfileName"
							:placeholder="$t('preferences.newProfilePlaceholder')"
							class="flex-1 min-w-0"
						/>
						<button
							@click="saveProfile"
							:disabled="!newProfileName"
							class="px-3 rounded-lg bg-[var(--bg-elevated)] hover:bg-[#E95420] hover:text-white text-[var(--text-secondary)] transition-all disabled:opacity-40"
							:aria-label="$t('preferences.saveProfile')"
						>
							<Plus class="w-4 h-4" />
						</button>
					</div>
				</div>
			</section>

			<StatusMessage :message="rightStatus" :type="rightError ? 'error' : 'success'" />

			<!-- Collapsible settings -->
			<section
				class="yaru-enter yaru-enter-3 bg-[var(--bg-card)] rounded-2xl border border-[var(--border-card)] overflow-hidden divide-y divide-[var(--border-card)]"
			>
				<div v-if="!isR1">
					<button
						@click="toggleSection('light')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.lightSettings') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'light' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'light'" class="px-4 pb-4 pt-1 space-y-3">
						<BaseSelect v-model="prefs.lightMode" :options="lightModes" />
						<div>
							<div class="text-xs text-[var(--text-muted)] mb-1">
								{{ $t('preferences.ledSpeed') }} ({{ prefs.ledSpeed }})
							</div>
							<BaseSlider v-model="prefs.ledSpeed" :min="1" :max="5" :step="1" />
						</div>
						<div class="flex items-center gap-2">
							<input
								type="color"
								:value="`#${prefs.rgb.r.toString(16).padStart(2, '0')}${prefs.rgb.g.toString(16).padStart(2, '0')}${prefs.rgb.b.toString(16).padStart(2, '0')}`"
								@input="
									(e: Event) => {
										const v = (e.target as HTMLInputElement).value;
										prefs.rgb.r = parseInt(v.slice(1, 3), 16);
										prefs.rgb.g = parseInt(v.slice(3, 5), 16);
										prefs.rgb.b = parseInt(v.slice(5, 7), 16);
									}
								"
								class="w-10 h-9 rounded-md cursor-pointer"
							/>
							<BaseInput
								type="number"
								v-model.number="prefs.rgb.r"
								:min="0"
								:max="255"
								class="flex-1 min-w-0"
							/>
							<BaseInput
								type="number"
								v-model.number="prefs.rgb.g"
								:min="0"
								:max="255"
								class="flex-1 min-w-0"
							/>
							<BaseInput
								type="number"
								v-model.number="prefs.rgb.b"
								:min="0"
								:max="255"
								class="flex-1 min-w-0"
							/>
						</div>
					</div>
				</div>

				<div>
					<button
						@click="toggleSection('polling')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.pollingSettings') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'polling' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'polling'" class="px-4 pb-4 pt-1">
						<BaseSelect v-model="prefs.pollingRate" :options="pollingOptions" />
					</div>
				</div>

				<div>
					<button
						@click="toggleSection('sleep')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.sleepSettings') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'sleep' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'sleep'" class="px-4 pb-4 pt-1 space-y-3">
						<div>
							<div class="text-xs text-[var(--text-muted)] mb-1">
								{{ $t('preferences.sleepTimer') }} ({{ prefs.sleepTime }} min)
							</div>
							<BaseSlider v-model="prefs.sleepTime" :min="0.5" :max="30" :step="0.5" />
						</div>
						<div>
							<div class="text-xs text-[var(--text-muted)] mb-1">
								{{ $t('preferences.deepSleepTimer') }} ({{ prefs.deepSleepTime }} min)
							</div>
							<BaseSlider v-model="prefs.deepSleepTime" :min="1" :max="60" :step="1" />
						</div>
					</div>
				</div>

				<div>
					<button
						@click="toggleSection('key')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.keyResponseSettings') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'key' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'key'" class="px-4 pb-4 pt-1">
						<BaseSelect v-model="prefs.keyResponse" :columns="4" :options="keyResponseOptions" />
					</div>
				</div>

				<div>
					<button
						@click="toggleSection('ripple')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.rippleControl') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'ripple' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'ripple'" class="px-4 pb-4 pt-1">
						<BaseToggle
							v-model="dpi.ripplerControl"
							:label="$t('dpi.rippleControl')"
							:description="$t('dpi.rippleControlDesc')"
						/>
					</div>
				</div>

				<div>
					<button
						@click="toggleSection('angle')"
						class="w-full flex items-center justify-between px-4 py-2.5 text-sm text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)] transition-all"
					>
						{{ $t('dashboard.angleSnap') }}
						<ChevronDown
							class="w-4 h-4 transition-transform duration-300"
							:class="openSection === 'angle' ? 'rotate-180' : ''"
						/>
					</button>
					<div v-show="openSection === 'angle'" class="px-4 pb-4 pt-1">
						<BaseToggle
							v-model="dpi.angleSnap"
							:label="$t('dpi.angleSnap')"
							:description="$t('dpi.angleSnapDesc')"
						/>
					</div>
				</div>
			</section>
		</div>
	</div>

	<!-- Floating remap menu (escapes the panel, like the vendor driver) -->
	<button
		v-if="openMenu !== null"
		@click="closeMenu"
		class="fixed inset-0 z-20 cursor-default"
		aria-label="Close menu"
		tabindex="-1"
	/>
	<div
		v-if="openMenu !== null"
		class="fixed z-30 bg-[var(--bg-card)] border border-[var(--border-card)] rounded-xl shadow-2xl shadow-black/60 overflow-hidden"
		:style="{ top: menuAnchor.top + 'px', left: menuAnchor.left + 'px', width: menuAnchor.width + 'px' }"
	>
		<div
			class="px-4 py-2 border-b border-[var(--border-card)] bg-[#E95420]/10 text-sm font-semibold text-[#f9a88a] truncate"
		>
			{{ buttonNames[menuButton] }}
		</div>
		<div class="py-1">
			<template v-for="group in REMAP_MENU" :key="group.key">
				<template v-if="!group.labelKey">
					<button
						v-for="item in group.items"
						:key="item"
						@click="applyMapping(menuButton, item)"
						:class="[
							'w-full text-left px-4 py-1.5 text-sm transition-colors',
							assignments[menuButton] === item
								? 'text-[#E95420] bg-[#E95420]/10 font-medium'
								: 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)]',
						]"
					>
						{{ remapLabel(item) }}
					</button>
				</template>
				<template v-else>
					<button
						@click="toggleSub(group.key, $event)"
						:class="[
							'w-full flex items-center justify-between pl-4 pr-2 py-1.5 text-sm transition-colors',
							openSub === group.key
								? 'text-[#f9a88a] bg-[#E95420]/15'
								: 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)]',
						]"
					>
						{{ group.labelKey ? $t(group.labelKey) : group.key }}
						<span class="text-sm leading-none">›</span>
					</button>
				</template>
			</template>
		</div>
	</div>

	<!-- Separate submenu panel (pops out to the side, like the vendor driver) -->
	<div
		v-if="openMenu !== null && openSub !== null"
		class="fixed z-40 bg-[var(--bg-card)] border border-[var(--border-card)] rounded-xl shadow-2xl shadow-black/60 overflow-hidden"
		:style="{
			top: subAnchor.top + 'px',
			left: menuAnchor.left + menuAnchor.width + 6 + 'px',
			width: '200px',
		}"
	>
		<div class="py-1">
			<template v-for="group in REMAP_MENU.filter((g) => g.key === openSub)" :key="group.key">
				<button
					v-for="item in group.items"
					:key="item"
					@click="applyMapping(menuButton, item)"
					:class="[
						'w-full text-left px-4 py-1.5 text-sm transition-colors',
						assignments[menuButton] === item
							? 'text-[#E95420] bg-[#E95420]/10 font-medium'
							: 'text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--surface-hover)]',
					]"
				>
					{{ remapLabel(item) }}
				</button>
			</template>
		</div>
	</div>
</template>
