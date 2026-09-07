"""Generate the checked-in Xcode project without third-party build dependencies."""
from pathlib import Path
import hashlib, json, plistlib
root = Path(__file__).resolve().parents[1] / 'Unscroll_Xcode_V1'
original = json.loads((root / 'MacProjectSettings.json').read_text())
objects = {}
def oid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(name, body):
    key=oid(name); objects[key]=body; return key
def q(s): return json.dumps(str(s))
def arr(items): return '(' + ','.join(items) + ',)' if items else '()'
core=['Core/PoseCounter.swift','Core/Economy.swift','Core/Wellbeing.swift','Core/PreviewProjection.swift']
shared=['Unscroll/SharedStorage.swift','Unscroll/ShieldPolicy.swift']
app=core+shared+['Unscroll/'+x for x in ['AppStore.swift','UnscrollApp.swift','ContentView.swift','WorkoutView.swift','PoseCamera.swift','ScreenTimeController.swift','WellbeingServices.swift','Design.swift','FocusView.swift','SleepView.swift','JourneyView.swift','WakeAlarm.swift','SkeletonOverlay.swift']]
monitor=core+shared+['Monitor/ActivityMonitor.swift']
refs={}
for path in sorted(set(app+monitor)):
    refs[path]=add(path, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(path)}; sourceTree = "<group>";')
asset = add('asset', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Unscroll/Asset.xcassets; sourceTree = "<group>";')
assetbuild = add('assetbuild', f'isa = PBXBuildFile; fileRef = {asset};')
refs['Unscroll/Asset.xcassets'] = asset
privacy=add('privacy', 'isa = PBXFileReference; lastKnownFileType = text.xml; path = Unscroll/PrivacyInfo.xcprivacy; sourceTree = "<group>";')
refs['Unscroll/PrivacyInfo.xcprivacy'] = privacy
config=add('Config.xcconfig','isa = PBXFileReference; lastKnownFileType = text.xcconfig; path = Config.xcconfig; sourceTree = "<group>";')
product_app=add('productapp','isa = PBXFileReference; explicitFileType = wrapper.application; path = Unscroll.app; sourceTree = BUILT_PRODUCTS_DIR;')
product_ext=add('productext','isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; path = UnscrollMonitor.appex; sourceTree = BUILT_PRODUCTS_DIR;')
products=add('products',f'isa = PBXGroup; name = Products; children = {arr([product_app,product_ext])}; sourceTree = "<group>";')
group=add('group',f'isa = PBXGroup; children = {arr(list(refs.values())+[config,products])}; sourceTree = "<group>";')
def settings(values): return '{'+' '.join(k+' = '+q(v)+';' for k,v in values.items())+'}'
def configurations(name, values, base=False):
    configs=[]
    for mode in ['Debug','Release']:
        v=dict(original.get(name, {}).get(mode, {}))
        v.update(values)
        if name=='project': v.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O',DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym',SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG' if mode=='Debug' else '')
        configs.append(add(name+mode,'isa = XCBuildConfiguration; '+(f'baseConfigurationReference = {config}; ' if base else '')+f'buildSettings = {settings(v)}; name = {mode};'))
    return add(name+'configlist',f'isa = XCConfigurationList; buildConfigurations = {arr(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
projectconfig=configurations('project',dict(SDKROOT='iphoneos',IPHONEOS_DEPLOYMENT_TARGET='17.4',SWIFT_VERSION='5.0',CLANG_ENABLE_MODULES='YES',CODE_SIGN_STYLE='Automatic',CURRENT_PROJECT_VERSION='4',MARKETING_VERSION='1.2.1',TARGETED_DEVICE_FAMILY='1'),True)
embedbuild=add('embedbuild',f'isa = PBXBuildFile; fileRef = {product_ext}; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy,);}};')
embed=add('embed',f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 13; files = ({embedbuild},); name = "Embed App Extensions"; runOnlyForDeploymentPostprocessing = 0;')
proxy=add('proxy',f'isa = PBXContainerItemProxy; containerPortal = {oid("project")}; proxyType = 1; remoteGlobalIDString = {oid("UnscrollMonitor")}; remoteInfo = UnscrollMonitor;')
dep=add('dependency',f'isa = PBXTargetDependency; target = {oid("UnscrollMonitor")}; targetProxy = {proxy};')
for name, paths, product, bundle, info, entitlements in [
    ('Unscroll',app,product_app,'$(UNSCROLL_APP_BUNDLE_ID)','Unscroll/Info.plist','Unscroll/Unscroll.entitlements'),
    ('UnscrollMonitor',monitor,product_ext,'$(UNSCROLL_APP_BUNDLE_ID).monitor','Monitor/Info.plist','Monitor/Monitor.entitlements')]:
    builds=[add(name+p,f'isa = PBXBuildFile; fileRef = {refs[p]};') for p in paths]
    sources=add(name+'sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
    frameworks=add(name+'frameworks','isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
    privacybuild=add(name+'privacy', f'isa = PBXBuildFile; fileRef = {privacy};')
    resources=add(name+'resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(([assetbuild] if name=="Unscroll" else [])+[privacybuild])}; runOnlyForDeploymentPostprocessing = 0;')
    values=dict(PRODUCT_BUNDLE_IDENTIFIER=bundle,PRODUCT_NAME='$(TARGET_NAME)',INFOPLIST_FILE=info,CODE_SIGN_ENTITLEMENTS=entitlements,GENERATE_INFOPLIST_FILE='NO',LD_RUNPATH_SEARCH_PATHS='$(inherited) @executable_path/Frameworks'+(' @executable_path/../../Frameworks' if name!='Unscroll' else ''),SUPPORTED_PLATFORMS='iphoneos iphonesimulator')
    values.update(CURRENT_PROJECT_VERSION='4', MARKETING_VERSION='1.2.1')
    if name!='Unscroll': values.update(APPLICATION_EXTENSION_API_ONLY='YES',SKIP_INSTALL='YES')
    conf=configurations(name,values)
    phases=[sources,frameworks,resources]+([embed] if name=='Unscroll' else [])
    typ='com.apple.product-type.application' if name=='Unscroll' else 'com.apple.product-type.app-extension'
    add(name,f'isa = PBXNativeTarget; buildConfigurationList = {conf}; buildPhases = {arr(phases)}; buildRules = (); dependencies = {arr([dep] if name=="Unscroll" else [])}; name = {name}; productName = {name}; productReference = {product}; productType = {q(typ)};')
add('project',f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600;}}; buildConfigurationList = {projectconfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = de; knownRegions = (de,en,Base,); mainGroup = {group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({oid("Unscroll")},{oid("UnscrollMonitor")},);')
(root/'Unscroll.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(k+' = {'+v+'};' for k,v in objects.items())+'\n}; rootObject = '+oid('project')+'; }\n')
base=dict(CFBundleDevelopmentRegion='de',CFBundleExecutable='$(EXECUTABLE_NAME)',CFBundleIdentifier='$(PRODUCT_BUNDLE_IDENTIFIER)',CFBundleInfoDictionaryVersion='6.0',CFBundleName='$(PRODUCT_NAME)',CFBundleShortVersionString='$(MARKETING_VERSION)',CFBundleVersion='$(CURRENT_PROJECT_VERSION)',UnscrollAppGroup='$(UNSCROLL_APP_GROUP)')
appinfo=dict(base,CFBundlePackageType='APPL',CFBundleDisplayName='Unscroll',LSRequiresIPhoneOS=True,NSCameraUsageDescription='Unscroll erkennt Liegestütze, Kniebeugen und Plank auf deinem iPhone. Kamerabilder werden nicht gespeichert.',UILaunchScreen={},UISupportedInterfaceOrientations=['UIInterfaceOrientationPortrait'],ITSAppUsesNonExemptEncryption=False)
appinfo = dict(original['info'], **appinfo)
appinfo.update(NSAlarmKitUsageDescription='Unscroll weckt dich zu deiner gewählten Aufstehzeit mit einem sanften Start und einem zweiten Alarm.', NSMotionUsageDescription='Unscroll zählt deine Schritte, um dir Zeitguthaben gutzuschreiben.', NSGKFriendListUsageDescription='Unscroll zeigt deine Game-Center-Freunde zum gemeinsamen Dranbleiben.', UIBackgroundModes=['audio'])
extinfo=dict(base,CFBundlePackageType='XPC!',NSExtension=dict(NSExtensionPointIdentifier='com.apple.deviceactivity.monitor-extension',NSExtensionPrincipalClass='$(PRODUCT_MODULE_NAME).ActivityMonitor'))
for path,data in [('Unscroll/Info.plist',appinfo),('Monitor/Info.plist',extinfo)]: (root/path).write_bytes(plistlib.dumps(data))
ent={'com.apple.developer.family-controls':True,'com.apple.security.application-groups':['$(UNSCROLL_APP_GROUP)']}
for path in ['Unscroll/Unscroll.entitlements','Monitor/Monitor.entitlements']:
    merged = dict(original['entitlements']) if path.startswith('Unscroll/') else {}
    merged.update(ent)
    (root/path).write_bytes(plistlib.dumps(merged))
scheme=root/'Unscroll.xcodeproj/xcshareddata/xcschemes/Unscroll.xcscheme'
scheme.parent.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{oid("Unscroll")}" BuildableName="Unscroll.app" BlueprintName="Unscroll" ReferencedContainer="container:Unscroll.xcodeproj"/>'
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug"/>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(f'Generated {len(objects)} Xcode objects, app + embedded monitor')
