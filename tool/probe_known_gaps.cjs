// Diagnostic evidence, not a passing security suite. ALLOWED results can be vulnerabilities.
// Run only through the local demo emulator; see the deep audit report.
const {createRequire} = require('node:module');
const req = createRequire(require('node:path').resolve('functions/package.json'));
const fs = require('node:fs');
const {initializeTestEnvironment} = req('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,Timestamp} = req('firebase/firestore');
async function main() {
  if (!/^127\.0\.0\.1:\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST || '')) throw Error('Local emulator required');
  const [host,port]=process.env.FIRESTORE_EMULATOR_HOST.split(':');
  const env=await initializeTestEnvironment({projectId:'demo-asb-audit',firestore:{host,port:Number(port),rules:fs.readFileSync('firestore.rules','utf8')}});
  const results=[];
  async function seed(path,data) { await env.withSecurityRulesDisabled(ctx=>setDoc(doc(ctx.firestore(),path),data)); }
  async function probe(id,description,action) {
    try {await action();results.push({id,description,result:'ALLOWED'});} catch(e) {results.push({id,description,result:'DENIED',code:e.code});}
  }
  try {
    await env.clearFirestore();
    const evil=env.authenticatedContext('unverified',{email:'someone@outside.test',email_verified:false}).firestore();
    const profile={scholar_no:'99999',full_name:'Test Alias',role:'student',house_name:'ruby',grade:10};
    await probe('O02a','New account can claim a different scholar identity',()=>setDoc(doc(evil,'users/unverified'),profile));
    await seed('classes/10A/report_cards/victim',{scholar_no:'99999',grades:{Math:90}});
    await probe('O02b','Forged scholar profile can read victim report card',()=>getDoc(doc(evil,'classes/10A/report_cards/victim')));
    const bootstrap=env.authenticatedContext('bootstrap',{email:'admin@asianschool.bh',email_verified:false}).firestore();
    await probe('O01','Unverified bootstrap email grants admin write without a user profile',()=>setDoc(doc(bootstrap,'system_config/probe'),{probe:true}));
    await probe('O07','Any signed-in user can send official-looking notifications to another user',()=>setDoc(doc(evil,'users/victim/notifications/probe'),{title:'Test Official Notice',body:'Test only',timestamp:Timestamp.now(),priority:'urgent'}));
    await probe('O21','Student can create a zero-price verified merchandise order',()=>setDoc(doc(evil,'orders/probe'),{receipt_id:'probe',items:[{id:'merch',qty:100}],status:'verified',user_id:'unverified',total_bhd:0,total_pts:0}));
    await probe('O08','Student can self-assert AI verified metadata on a pending claim',()=>setDoc(doc(evil,'house_claims/probe'),{scholar_no:'99999',student_name:'Test Alias',house_name:'topaz',activity_title:'Test claim',points:500,cert_url:'https://example.test/cert.jpg',status:'pending',ai_status:'verified',ai_confidence:100,auto_validated:true}));
    await probe('O27','New chat room existence check',()=>getDoc(doc(evil,'chats/new-room')));
    await seed('chats/room',{participants:['unverified','staff']});
    await probe('O28','Client photo message payload rejected by schema',()=>setDoc(doc(evil,'chats/room/messages/probe'),{sender_id:'unverified',sender_name:'Test',text:'Photo',attachment_url:'data:image/jpeg;base64,AA==',timestamp:Timestamp.now(),is_read:false,push_alert_triggered:true}));
    const admin=env.authenticatedContext('admin',{admin:true}).firestore();
    await probe('O19','Current trophy model payload rejected for admin',()=>setDoc(doc(admin,'sports_trophies/probe'),{trophy_id:'probe',tournament_title:'Test',sport_type:'football',winning_house:'ruby',runner_up_house:'topaz',points_awarded:100,runner_up_points:50,mvp_scholar_no:null,mvp_name:null,awarded_at:new Date().toISOString(),commissioner_name:'Test',trophy_tier:'goldCup'}));
    await seed('users/suspended',{...profile,role:'teacher',status:'suspended'});
    const suspended=env.authenticatedContext('suspended').firestore();
    await seed('medical_leaves/private',{scholar_no:'12345',student_name:'Private',status:'pending'});
    await probe('O04','Suspended teacher still has staff access to medical records',()=>getDoc(doc(suspended,'medical_leaves/private')));
    const noProfile=env.authenticatedContext('no-profile').firestore();
    await seed('events/senior',{status:'published',house_scope:'all',grade_min:11,grade_max:12,end_time:Timestamp.fromMillis(Date.now()+60000)});
    await probe('O33','Account without grade/profile can register for senior-only event',()=>setDoc(doc(noProfile,'events/senior/registrations/no-profile'),{uid:'no-profile',event_id:'senior'}));
    fs.mkdirSync('audit/2026-11-26',{recursive:true});
    fs.writeFileSync('audit/2026-11-26/known-gap-probes.json',JSON.stringify({scope:'Local demo emulator only; expected release blockers, not passing security assertions',results},null,2)+'\n');
    console.log(JSON.stringify(results,null,2));
  } finally { await env.cleanup(); }
}
main().catch(e=>{console.error(e);process.exitCode=1;});
