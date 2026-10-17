// Cat types and data loader for a TypeScript frontend.
// Copy specs/cats-and-actions.json into your app or import with resolveJsonModule.
export type CatId = 'fluffy_b' | 'orange_c';
export type Playback = 'loop' | 'once' | 'hold';
export interface ActionDefinition {
  id: string;
  label: string;
  category: string;
  playback: Playback;
  frames: string[];
  suggestedTrigger: string;
  assetStatus: 'TO_CREATE' | 'READY';
}
export interface CatDefinition {
  id: CatId;
  name: string;
  style: string;
  reference: string;
  assetDirectory: string;
  colorways: string[];
}
export interface CatManifest {
  schemaVersion: number;
  cats: CatDefinition[];
  actions: ActionDefinition[];
  notes: string[];
}
export const defaultPetSettings = {
  catId: 'fluffy_b' as CatId,
  scale: 3,
  alwaysOnTop: true,
  startAtLogin: false,
  idleAnimations: true,
  followCursor: false,
  allowWindowInteractions: false,
  soundEnabled: false,
  reducedMotion: false,
  pauseOnFullscreen: true,
};
