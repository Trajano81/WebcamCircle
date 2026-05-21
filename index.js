'use strict';
const path = require('path');
const {app, BrowserWindow, Menu, shell} = require('electron');

const REPO_URL = 'https://github.com/Trajano81/WebcamCircle';
const isMacOS = process.platform === 'darwin';

// Note: must match `build.appId` in package.json
app.setAppUserModelId('com.cainhill.WebcamCircle');

// Prevent window from being garbage collected
let mainWindow;

const buildMenu = () => {
	const helpSubmenu = [
		{
			label: 'Website',
			click() {
				shell.openExternal(REPO_URL);
			}
		},
		{
			label: 'Report an Issue',
			click() {
				shell.openExternal(`${REPO_URL}/issues/new`);
			}
		}
	];

	const macosTemplate = [
		{
			label: 'WebcamCircle',
			submenu: [
				{role: 'about'},
				{type: 'separator'},
				{role: 'services'},
				{type: 'separator'},
				{role: 'hide'},
				{role: 'hideOthers'},
				{role: 'unhide'},
				{type: 'separator'},
				{role: 'quit'}
			]
		},
		{role: 'editMenu'},
		{role: 'viewMenu'},
		{role: 'windowMenu'},
		{role: 'help', submenu: helpSubmenu}
	];

	const otherTemplate = [
		{
			role: 'fileMenu',
			submenu: [
				{role: 'quit'}
			]
		},
		{role: 'editMenu'},
		{role: 'viewMenu'},
		{role: 'help', submenu: helpSubmenu}
	];

	return Menu.buildFromTemplate(isMacOS ? macosTemplate : otherTemplate);
};

const createMainWindow = async () => {
	const win = new BrowserWindow({
		title: app.name,
		show: false,
		// https://www.electronjs.org/docs/api/browser-window
		maximizable: false,
		minimizable: false,
		acceptFirstMouse: true,
		width: 400,
		height: 400,
		// https://stackoverflow.com/questions/44391448/electron-require-is-not-defined
		webPreferences: {
			nodeIntegration: true,
			contextIsolation: false,
			devTools: false
		},
		// https://github.com/MaybeRex/Electron-Webcam/blob/master/src/main.js
		frame: false,
		resizable: false,
		// https://github.com/electron/electron/issues/20933
		alwaysOnTop: true,
		// https://ourcodeworld.com/articles/read/315/how-to-create-a-transparent-window-with-electron-framework
		transparent: true,
		// Disable the macOS drop shadow so the window outline does not
		// render a rectangle when the below-circle name label extends
		// the body's content area past the circle.
		hasShadow: false
	});

	win.on('ready-to-show', () => {
		win.show();
	});

	win.on('closed', () => {
		mainWindow = undefined;
	});

	await win.loadFile(path.join(__dirname, 'index.html'));

	return win;
};

if (!app.requestSingleInstanceLock()) {
	app.quit();
}

app.on('second-instance', () => {
	if (mainWindow) {
		if (mainWindow.isMinimized()) {
			mainWindow.restore();
		}

		mainWindow.show();
	}
});

app.on('window-all-closed', () => {
	if (!isMacOS) {
		app.quit();
	}
});

app.on('activate', async () => {
	if (!mainWindow) {
		mainWindow = await createMainWindow();
	}
});

(async () => {
	await app.whenReady();
	Menu.setApplicationMenu(buildMenu());
	mainWindow = await createMainWindow();
})();
