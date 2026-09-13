import { app } from 'electron';
import type { StageIndex } from '../driver/protocols/DpiBuilder.js';
import { MacroName } from '../../shared/macro-templates.js';
import fs from 'fs/promises';
import path from 'path';

const getSettingsPath = (): string => path.join(app.getPath('userData'), 'settings.json');

export interface AppSettings {
	lastTab: string;
	connectionMode: 'Adapter' | 'Wired';
	deviceModel: 'X11' | 'X11SE' | 'R1';
	language: string;
	preferences: {
		lightMode: number;
		ledSpeed: number;
		keyResponse: number;
		pollingRate: number;
		sleepTime: number;
		deepSleepTime: number;
		rgb: { r: number; g: number; b: number };
	};
	dpiConfig: {
		activeStage: StageIndex;
		angleSnap: boolean;
		ripplerControl: boolean;
		dpiValues: [number, number, number, number, number, number];
	};
	mappings: Record<number, MacroName>;
}

const DEFAULT_SETTINGS: AppSettings = {
	lastTab: 'preferences',
	connectionMode: 'Adapter',
	deviceModel: 'X11',
	language: 'en',
	preferences: {
		lightMode: 0x20, // Breathing
		ledSpeed: 2,
		keyResponse: 4,
		pollingRate: 1000,
		sleepTime: 2,
		deepSleepTime: 10,
		rgb: { r: 255, g: 0, b: 255 },
	},
	dpiConfig: {
		activeStage: 2,
		angleSnap: false,
		ripplerControl: true,
		dpiValues: [800, 1600, 2400, 3200, 5000, 22000],
	},
	mappings: {
		0: MacroName.GLOBAL_LEFT_CLICK,
		1: MacroName.GLOBAL_RIGHT_CLICK,
		2: MacroName.GLOBAL_MIDDLE,
		3: MacroName.GLOBAL_FORWARD,
		4: MacroName.GLOBAL_BACKWARD,
		5: MacroName.GLOBAL_DPI_CYCLE,
	},
};

function toNum(v: unknown, fallback: number): number {
	const n = Number(v);
	return Number.isFinite(n) ? n : fallback;
}

function toMappings(saved: unknown): Record<number, MacroName> {
	const out = { ...DEFAULT_SETTINGS.mappings };
	if (saved && typeof saved === 'object') {
		for (const [k, v] of Object.entries(saved)) {
			const btn = Number(k);
			if (
				Number.isInteger(btn) &&
				btn >= 0 &&
				btn <= 5 &&
				typeof v === 'string' &&
				(Object.values(MacroName) as string[]).includes(v)
			) {
				out[btn] = v as MacroName;
			}
		}
	}
	return out;
}

export async function getSettings(): Promise<AppSettings> {
	try {
		const data = await fs.readFile(getSettingsPath(), 'utf-8');
		const saved = JSON.parse(data);
		return {
			...DEFAULT_SETTINGS,
			...saved,
			deviceModel: saved.deviceModel === 'R1' ? 'R1' : 'X11',
			preferences: {
				...DEFAULT_SETTINGS.preferences,
				...saved.preferences,
				lightMode: toNum(saved.preferences?.lightMode, DEFAULT_SETTINGS.preferences.lightMode),
				ledSpeed: toNum(saved.preferences?.ledSpeed, DEFAULT_SETTINGS.preferences.ledSpeed),
				keyResponse: toNum(saved.preferences?.keyResponse, DEFAULT_SETTINGS.preferences.keyResponse),
				pollingRate: toNum(saved.preferences?.pollingRate, DEFAULT_SETTINGS.preferences.pollingRate),
				sleepTime: toNum(saved.preferences?.sleepTime, DEFAULT_SETTINGS.preferences.sleepTime),
				deepSleepTime: toNum(saved.preferences?.deepSleepTime, DEFAULT_SETTINGS.preferences.deepSleepTime),
				rgb: {
					r: toNum(saved.preferences?.rgb?.r, DEFAULT_SETTINGS.preferences.rgb.r),
					g: toNum(saved.preferences?.rgb?.g, DEFAULT_SETTINGS.preferences.rgb.g),
					b: toNum(saved.preferences?.rgb?.b, DEFAULT_SETTINGS.preferences.rgb.b),
				},
			},
			dpiConfig: {
				...DEFAULT_SETTINGS.dpiConfig,
				...saved.dpiConfig,
				activeStage: toNum(saved.dpiConfig?.activeStage, DEFAULT_SETTINGS.dpiConfig.activeStage),
				dpiValues: (saved.dpiConfig?.dpiValues ?? DEFAULT_SETTINGS.dpiConfig.dpiValues).map((v: unknown) =>
					toNum(v, 800),
				) as [number, number, number, number, number, number],
			},
			mappings: toMappings(saved.mappings),
		};
	} catch {
		return DEFAULT_SETTINGS;
	}
}

export async function saveSettings(settings: AppSettings): Promise<void> {
	await fs.writeFile(getSettingsPath(), JSON.stringify(settings, null, 2));
}
