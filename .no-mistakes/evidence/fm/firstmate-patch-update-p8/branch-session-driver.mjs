import { mkdirSync, cpSync, symlinkSync, writeFileSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const root='/source', fixture='/tmp/fm-branch-proof', home='/tmp/fm-home', agentDir='/tmp/fm-agent';
mkdirSync(`${fixture}/.pi/extensions/lib`,{recursive:true}); mkdirSync(`${fixture}/node_modules/@earendil-works`,{recursive:true}); mkdirSync(`${home}/state`,{recursive:true}); mkdirSync(`${home}/config`,{recursive:true}); mkdirSync(agentDir,{recursive:true});
for (const name of ['fm-branch-dispatch','fm-native-contract','fm-async-exec','fm-branch-model-picker','fm-calm-visibility','fm-operational-input']) cpSync(`${root}/.pi/extensions/lib/${name}.ts`,`${fixture}/.pi/extensions/lib/${name}.ts`);
cpSync(`${root}/.pi/extensions/fm-branch-supervision.ts`,`${fixture}/.pi/extensions/fm-branch-supervision.ts`);
const pkg='/usr/local/lib/node_modules/@earendil-works/pi-coding-agent';
symlinkSync(pkg,`${fixture}/node_modules/@earendil-works/pi-coding-agent`);
for(const name of ['@earendil-works/pi-tui','@earendil-works/pi-ai','typebox']) { const [scope,part]=name.startsWith('@')?name.split('/'):['',name]; const dir=scope?`${fixture}/node_modules/${scope}`:`${fixture}/node_modules`; mkdirSync(dir,{recursive:true}); symlinkSync(`${pkg}/node_modules/${name}`,`${dir}/${part}`); }
writeFileSync(`${fixture}/package.json`,'{"type":"module"}');
writeFileSync(`${agentDir}/models.json`,JSON.stringify({providers:{'fm-local':{baseUrl:'https://fm-local.invalid/v1',api:'openai-completions',apiKey:'placeholder',models:[{id:'fm-model',name:'local',contextWindow:8192,maxTokens:512}]}}}));
process.env.FM_HOME=home;process.env.FM_ROOT_OVERRIDE=root;process.env.PI_CODING_AGENT_DIR=agentDir;
const {DefaultResourceLoader,ModelRegistry,ModelRuntime,SessionManager,SettingsManager,createAgentSession,InteractiveMode,initTheme}=await import(pathToFileURL(`${pkg}/dist/index.js`).href);
initTheme('dark');
const settings=SettingsManager.create(fixture,agentDir);
const loader=new DefaultResourceLoader({cwd:fixture,agentDir,settingsManager:settings,additionalExtensionPaths:[`${fixture}/.pi/extensions/fm-branch-supervision.ts`],noSkills:true,noPromptTemplates:true,noThemes:true,noContextFiles:true});
await loader.reload();
const runtime=await ModelRuntime.create({authPath:`${agentDir}/auth.json`,modelsPath:`${agentDir}/models.json`});const registry=new ModelRegistry(runtime);await registry.refresh();
const model=registry.find('fm-local','fm-model');if(!model)throw Error('model not found');
const {session}=await createAgentSession({cwd:fixture,sessionManager:SessionManager.create(fixture,'/tmp/fm-sessions'),settingsManager:settings,resourceLoader:loader,modelRuntime:runtime,model,noTools:'builtin'});
const tool=session.getToolDefinition('fm_branch_outcomes');if(!tool)throw Error('real Pi did not register fm_branch_outcomes');
const calls=[{}, {recent:0},{recent:1.5},{recent:2e100},{recent:2}];let turn=0;const observed=[];
const encoder=new TextEncoder();
globalThis.fetch=async(input,options)=>{const url=typeof input==='string'?input:input.url;if(!url.startsWith('https://fm-local.invalid/'))throw Error(`unexpected fetch ${url}`);
 const request=JSON.parse(options.body); const call=calls[turn++]; const messages=request.messages;
 const response=call?{id:`completion-${turn}`,object:'chat.completion.chunk',created:1,model:'fm-model',choices:[{index:0,delta:{role:'assistant',tool_calls:[{index:0,id:`call_${turn}`,type:'function',function:{name:'fm_branch_outcomes',arguments:JSON.stringify(call)}}]},finish_reason:null}]}:{id:`completion-${turn}`,object:'chat.completion.chunk',created:1,model:'fm-model',choices:[{index:0,delta:{role:'assistant',content:'Done.'},finish_reason:null}]};
 const finish={id:`completion-${turn}`,object:'chat.completion.chunk',created:1,model:'fm-model',choices:[{index:0,delta:{},finish_reason:call?'tool_calls':'stop'}],usage:{prompt_tokens:10,completion_tokens:10,total_tokens:20}};
 return new Response(`data: ${JSON.stringify(response)}\n\ndata: ${JSON.stringify(finish)}\n\ndata: [DONE]\n\n`,{status:200,headers:{'content-type':'text/event-stream'}});
};
const seen=[];const unsubscribe=session.subscribe(event=>{if(['tool_execution_start','tool_execution_end','message_end'].includes(event.type))seen.push(event);});
const host={session,setBeforeSessionInvalidate(){},setRebindSession(){}};const interactive=new InteractiveMode(host,{tuiMode:'alt-screen'});interactive.isInitialized=true;interactive.subscribeToAgent();
try{await session.prompt('Read branch outcomes.');
 const messageRows=session.messages.filter(m=>m.role==='assistant').flatMap(m=>m.content.filter(c=>c.type==='toolCall'));
 if(messageRows.length!==5)throw Error(`expected five real session tool calls; turn=${turn}; messages=${JSON.stringify(session.messages).slice(0,5000)}; events=${JSON.stringify(seen).slice(0,5000)}`);
 const {ToolExecutionComponent}=await import(pathToFileURL(`${pkg}/dist/modes/interactive/components/tool-execution.js`).href);
 const ui={requestRender(){}};const stock={...tool};delete stock.renderShell;delete stock.renderCall;delete stock.renderResult;
 const proof=[];
 for(let i=0;i<5;i++){
  const args=messageRows[i].arguments;const id=messageRows[i].id;const result=seen.find(x=>x.type==='tool_execution_end'&&x.toolCallId===id);if(!result)throw Error(`missing completed session tool ${id}`);
  const actualComponent=interactive.chatContainer.children.find(c=>c instanceof ToolExecutionComponent&&c.toolCallId===id);
  if(!actualComponent)throw Error(`real Pi TUI missing call ${id}; children=${interactive.chatContainer.children.map(c=>c.constructor.name)}`);
  const baseline=new ToolExecutionComponent('fm_branch_outcomes',`stock-${i}`,args,{showImages:false},stock,ui,fixture);baseline.markExecutionStarted();baseline.setArgsComplete();baseline.updateResult(result.result);
  for(const width of [24,100])for(const expanded of [false,true]){actualComponent.setExpanded(expanded);baseline.setExpanded(expanded);const actual=actualComponent.render(width),expected=baseline.render(width);proof.push({args,width,expanded,actual,expected,equal:JSON.stringify(actual)===JSON.stringify(expected),isError:result.isError});if(JSON.stringify(actual)!==JSON.stringify(expected))throw Error(`stock mismatch: ${JSON.stringify(proof.at(-1))}`);}
 }
 for(const entry of proof){const visible=entry.actual.join('\n').replace(/\x1b\[[0-9;]*m/g,'');if(!visible.includes('fm_branch_outcomes'))throw Error(`no visible tool row for ${JSON.stringify(entry.args)}`);if('recent' in entry.args&&!visible.includes(String(entry.args.recent)))throw Error(`recent value missing from visible row: ${visible}`);}
 if(!proof.some(x=>x.isError)||!proof.some(x=>!x.isError))throw Error('missing success/error execution outcomes');
 if(JSON.stringify(proof[16].actual)===JSON.stringify(proof[17].actual))throw Error('collapsed/expanded recent=2 rows are identical');
 writeFileSync('/evidence/branch-session-results.json',JSON.stringify({calls:messageRows,events:seen.map(e=>({type:e.type,toolCallId:e.toolCallId,isError:e.isError,result:e.result})),proof,transcript:session.messages},null,2));
 writeFileSync('/evidence/branch-session-tui.txt',interactive.chatContainer.render(100).join('\n'));
 console.log(`REAL_SESSION_OK calls=${messageRows.length} comparisons=${proof.length} errors=${proof.filter(p=>p.isError).length}`);
}finally{interactive.unsubscribe();unsubscribe();session.dispose();}
