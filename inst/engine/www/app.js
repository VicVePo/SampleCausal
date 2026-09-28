"use strict";
const $=id=>document.getElementById(id);
const esc=v=>String(v??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const opNames={sample_size:"Tamaño muestral para una potencia objetivo",power:"Potencia con una muestra disponible",precision:"Tamaño para una precisión objetivo",minimum_detectable_effect:"Efecto mínimo detectable",recruitment_reestimation:"Reestimación del reclutamiento"};
const targetNames={ATE:"ATE · población total",ATT:"ATT · población tratada",ATC:"ATC · población control",ATO:"ATO · población con solapamiento",ATT_new_study:"ATT · tratados del nuevo estudio",externally_justified_matched_target:"Población emparejada previamente justificada"};
const methodNames={"M01.weights":"Efectos de diseño de los pesos","M01.adjusted_variance":"Varianza ajustada de un piloto (avanzado)","M02.table":"Discriminación y tabla de Austin","M03.normal":"Solapamiento y modelo del desenlace","M06.prediction":"Modelo predictivo con controles externos","M05.summary":"Resumen de remuestreos de emparejamiento"};
const ignored=new Set(["scheme","estimand","homogeneous_effect","q_definition","pilot_definition","resampling_metadata","pair_target_justification"]);
const kinds={explicit_assumption:"Supuesto explícito",publication:"Publicación",pilot:"Piloto",sensitivity_scenario:"Escenario de sensibilidad"};
const defaults={alpha:"0.05",target_power:"0.8",confidence:"0.95",loss:"0",alpha_ci:"0.05"};
let config,mod,fieldKeys=[],lastResult=null,lastPayload=null,lastSensitivity=null,lastSensitivityRequest=null,demo=false,revision=0,sensitivityRevision=0;
function options(el,items,keep){el.innerHTML=items.map(([v,t])=>'<option value="'+esc(v)+'">'+esc(t)+'</option>').join("");if(items.some(x=>x[0]===keep))el.value=keep;}
function methodsByDesign(){return config.modules.filter(m=>$("design").value==="external"?m.id==="M06.prediction":$("design").value==="matching"?m.id==="M05.summary":m.n_means==="total");}
function designChanged(){const list=methodsByDesign();const outcomes=[...new Set(list.flatMap(m=>m.outcomes))];options($("outcome"),outcomes.map(o=>[o,{continuous:"Continuo",binary:"Binario",outcome_agnostic:"Definido por el análisis emparejado"}[o]]),$("outcome").value);outcomeChanged();}
function outcomeChanged(){const list=methodsByDesign().filter(m=>m.outcomes.includes($("outcome").value));const targets=[...new Set(list.flatMap(m=>m.estimands))];options($("estimand"),targets.map(t=>[t,targetNames[t]||t]),$("estimand").value);targetChanged();}
function targetChanged(){const list=methodsByDesign().filter(m=>m.outcomes.includes($("outcome").value)&&m.estimands.includes($("estimand").value));options($("method"),list.map(m=>[m.id,methodNames[m.id]]),$("method").value);methodChanged();}
function limitationsHTML(id,items){
 const full='<ul class="restriction">'+items.map(t=>'<li>'+esc(t)+'</li>').join("")+'</ul>';
 if(id!=="M06.prediction")return full;
 return '<p><strong>M06-E1: varianza media corregida.</strong> La potencia y la precisión son aproximaciones normales.</p><ul class="restriction"><li>Se requieren al menos 100 grados de libertad residuales por grupo: n0 − p − 1 y n1 − p − 1. p no incluye el intercepto.</li><li>Modelo lineal correcto, covariables normales de igual distribución y errores normales independientes.</li><li>El cálculo promedia posibles bases históricas; no garantiza el resultado para una base histórica concreta.</li></ul><details><summary>Derivación, evidencia y alcance</summary>'+full+'</details>';
}
function methodChanged(){mod=config.modules.find(m=>m.id===$("method").value);options($("operation"),mod.functions.map(o=>[o,opNames[o]]),$("operation").value);$("methodnote").innerHTML=limitationsHTML(mod.id,mod.limitations);$("source").href=mod.reference.url;demo=false;$("demolabel").hidden=true;renderFields(false);invalidate();}
function numericValue(key){const value=$("f_"+key).value.trim();if(!value)return null;const normalized=value.replace(",",".");return /^[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?$/i.test(normalized)?Number(normalized):null;}
function label(key){return config.labels[key]||key;}
function domain(key){const d=mod.inputs?.[key]?.domain||"";return d.replaceAll("positive_finite","Valor positivo y finito").replaceAll("positive_integer","Entero positivo").replaceAll("nonnegative_integer","Entero no negativo").replaceAll("finite; nonzero for sample_size","Valor finito; distinto de cero para calcular tamaño").replaceAll(">=","≥").replaceAll("<=","≤");}
function renderFields(preserve=true){
 const old={},prov={};if(preserve)for(const k of fieldKeys){if($("f_"+k))old[k]=$("f_"+k).value;if($("p_"+k))prov[k]={kind:$("p_"+k).value,detail:$("d_"+k).value};}
 const prevTest=$("test")?.value||"two_sided",prevDirection=$("direction")?.value||"increase",prevMode=$("mode")?.value||"full_normal_integer";
 const operation=$("operation").value,binary=$("outcome").value==="binary",matching=mod.id==="M05.summary";
 let vars=mod.variance_parameter_inputs;if(!Array.isArray(vars))vars=vars[binary&&operation==="minimum_detectable_effect"?"binary_MDE":$("outcome").value];
 fieldKeys=vars.filter(k=>!ignored.has(k));
 if(!matching){
   if(["sample_size","power"].includes(operation)&&!(mod.id==="M01.weights"&&binary))fieldKeys.push("delta");
   if(["power","minimum_detectable_effect"].includes(operation))fieldKeys.push("sample_size");
   if(operation==="precision")fieldKeys.push("confidence","half_width");
   else{fieldKeys.push("alpha");if(operation!=="power")fieldKeys.push("target_power");}
   fieldKeys.push("loss");
 }
 fieldKeys=[...new Set(fieldKeys)];
 $("parameters").innerHTML=fieldKeys.map(k=>'<label>'+esc(label(k))+'<input id="f_'+k+'" inputmode="decimal" value="'+esc(old[k]??defaults[k]??"")+'" autocomplete="off" required><small>'+esc(domain(k))+'</small></label>').join("");
 if(!matching&&operation!=="precision"){
   $("parameters").insertAdjacentHTML("beforeend",'<label>Prueba<select id="test"><option value="two_sided">Bilateral</option><option value="one_sided">Unilateral</option></select></label><label>Dirección del efecto<select id="direction"><option value="increase">Aumento</option><option value="decrease">Disminución</option></select></label><label class="full">Procedimiento numérico<select id="mode"><option value="full_normal_integer">Menor entero que alcanza la potencia normal</option><option value="quantile_formula">Fórmula aproximada de cuantiles</option></select></label>');
   $("test").value=prevTest;$("direction").value=prevDirection;$("mode").value=prevMode;
   const updateDirection=()=>{$("direction").parentElement.hidden=$("test").value==="two_sided"&&operation!=="minimum_detectable_effect";};
   updateDirection();$("test").addEventListener("change",updateDirection);
 }
 if(!preserve){
  $("special").innerHTML=mod.id==="M03.normal"?'<label class="check"><input id="homogeneous" type="checkbox"><span>El modelo de planificación supone un efecto homogéneo.</span></label>':mod.id==="M01.adjusted_variance"?'<label class="check"><input id="qdefinition" type="checkbox"><span>q0 y q1 son σ² × deff con término de resto, según la sección 6 de Shook-Sa–Hudgens.</span></label><label>Definición y análisis del piloto<textarea id="pilot"></textarea></label>':matching?'<label>Justificación previa del número de pares<textarea id="pairtarget"></textarea></label><label>Procedimiento, número y resumen de los remuestreos<textarea id="resampling"></textarea></label>':"";
  $("confirm").checked=false;
 }
 $("unitslabel").hidden=matching;
 if(binary)$("units").value="diferencia absoluta de riesgos";else if(!preserve)$("units").value="";
 $("units").readOnly=binary;
 $("provenance").innerHTML=fieldKeys.map(k=>'<div class="provenance-row"><strong>'+esc(label(k))+'</strong><div class="grid"><label>Tipo de fuente<select id="p_'+k+'">'+Object.entries(kinds).map(([v,t])=>'<option value="'+v+'">'+t+'</option>').join("")+'</select></label><label>Referencia o justificación<input id="d_'+k+'" value="'+esc(prov[k]?.detail||"")+'" placeholder="Fuente y valor asumido" required></label></div></div>').join("");
 for(const k of fieldKeys)if(prov[k])$("p_"+k).value=prov[k].kind;
}
function invalidateSensitivity(){sensitivityRevision++;lastSensitivity=null;lastSensitivityRequest=null;$("sensitivityresult").textContent="";$("exportsensitivity").hidden=true;$("sensitivityexportstatus").textContent="";}
function invalidate(){revision++;lastResult=null;lastPayload=null;invalidateSensitivity();$("sensitivity").hidden=true;$("feedback").textContent="";if($("result").dataset.hasResult)$("result").innerHTML='<p class="stale">Los parámetros cambiaron. Calcula nuevamente para obtener un resultado actualizado.</p>';}
function buildPayload(){
 const p={module_id:mod.id,outcome:$("outcome").value,estimand:$("estimand").value,calculation:$("operation").value,scenario_name:$("scenario").value.trim(),effect_units:$("units").value.trim(),assumptions_confirmed:$("confirm").checked,provenance:{},demo};
 for(const k of fieldKeys){p[k]=numericValue(k);p.provenance[k]={kind:$("p_"+k).value,detail:$("d_"+k).value.trim()};}
 if($("test"))Object.assign(p,{test:$("test").value,direction:$("direction").value,mode:$("mode").value});
 if($("homogeneous"))p.homogeneous_effect=$("homogeneous").checked;
 if($("qdefinition"))Object.assign(p,{q_definition:$("qdefinition").checked?"M01_section6_sigma2_times_deff_with_remainder":"",pilot_definition:$("pilot").value});
 if($("pairtarget"))Object.assign(p,{pair_target_justification:$("pairtarget").value,resampling_metadata:$("resampling").value});
 return p;
}
function fmt(x){return typeof x==="number"?new Intl.NumberFormat("es-PE",{maximumSignificantDigits:7}).format(x):String(x);}
let rpcSequence=0;
const pendingRpc=new Map();
Shiny.addCustomMessageHandler("sc_response",message=>{
 const pending=pendingRpc.get(message.id);
 if(pending){clearTimeout(pending.timer);pendingRpc.delete(message.id);pending.resolve(JSON.parse(message.json));}
});
function post(url,p){
 return new Promise((resolve,reject)=>{
  const id="r"+(++rpcSequence);
  const timer=setTimeout(()=>{pendingRpc.delete(id);reject(new Error("Tiempo de espera agotado"));},60000);
  pendingRpc.set(id,{resolve,reject,timer});
  Shiny.setInputValue("sc_request",{id,route:url,payload:p??null},{priority:"event"});
 });
}
function downloadUrl(id){
 const anchor=$(id);
 if(!anchor||!anchor.getAttribute("href"))throw new Error("Descarga aún no disponible");
 return anchor.href;
}
async function exportToProject(kind){
 const request=kind==="sensitivity"?lastSensitivityRequest:lastPayload;
 if(!request)return;
 const epoch=revision,senEpoch=sensitivityRevision;
 const status=kind==="sensitivity"?$("sensitivityexportstatus"):$("savedstatus");
 const button=kind==="sensitivity"?$("exportsensitivity"):kind==="save"?$("saveproject"):kind==="json"?$("exportjson"):$("exporttext");
 button.disabled=true;status.textContent="Preparando archivo…";
 try{
  const saved=await post(kind==="sensitivity"?"/api/save-sensitivity":"/api/save",request);
  if(saved.status==="ok"){
   saved.download_json=downloadUrl(kind==="sensitivity"?"download_sensitivity":"download_json");
   if(kind!=="sensitivity")saved.download_text=downloadUrl("download_text");
  }
  if(epoch!==revision||(kind==="sensitivity"&&senEpoch!==sensitivityRevision))return;
  if(saved.status!=="ok"){status.textContent=saved.message;return;}
  status.textContent="Copia guardada en la carpeta del proyecto. ";
  const formats=kind==="save"?["json","text"]:[kind==="text"?"text":"json"];
  for(const format of formats){
   const link=document.createElement("a");link.href=saved["download_"+format];link.download="";
   link.textContent=format==="json"?"Descargar JSON":"Descargar justificación";
   status.append(link,document.createTextNode(" "));
   if(kind!=="save")link.click();
  }
 }catch(err){if(epoch===revision)status.textContent="No se pudo preparar el archivo. Comprueba que el servidor siga abierto.";}
 finally{button.disabled=false;}
}
function renderResult(r){
 const el=$("result");el.dataset.hasResult="true";
 if(r.status!=="ok"){el.innerHTML='<p class="eyebrow">REVISAR EL ESCENARIO</p><h2>'+esc(r.message)+'</h2><p class="muted">Estado: '+esc(r.status)+'</p>'+(r.details?'<pre>'+esc(JSON.stringify(r.details,null,2))+'</pre>':"");return;}
 let main,labeltext;const op=r.calculation;
 if(op==="minimum_detectable_effect"){main=fmt(r.minimum_detectable_effect);labeltext="Efecto mínimo detectable · "+r.inputs.effect_units;}
 else if(op==="power"){main=fmt(r.power_recalculated*100)+" %";labeltext="Potencia normal aproximada";}
 else if(op==="recruitment_reestimation"){main=fmt(r.n_additional);labeltext="Tratados adicionales por reclutar";}
 else{main=fmt(r.n_analyzable);labeltext=r.n_meaning==="new_treated"?"Tratados nuevos analizables":"Participantes analizables en total";}
 const facts=[];
 if(r.n_treated_final!==undefined)facts.push(["Tratados totales",r.n_treated_final]);
 if(r.power_recalculated!==undefined&&op!=="power")facts.push(["Potencia normal recalculada",fmt(r.power_recalculated*100)+" %"]);
 if(r.n_analyzable!==undefined&&["power","minimum_detectable_effect"].includes(op))facts.push([r.n_meaning==="new_treated"?"Tratados nuevos analizables":"Muestra analizable total",r.n_analyzable]);
 if(r.n_recruit_expected!==undefined&&r.inputs.loss>0)facts.push(["Reclutamiento con pérdidas esperadas",r.n_recruit_expected]);
 if(r.expected_group_counts){facts.push(["Tratados esperados",fmt(r.expected_group_counts.treated)],["Controles esperados",fmt(r.expected_group_counts.control)]);}
 if(r.n_external_fixed!==undefined)facts.push(["Controles externos fijos",r.n_external_fixed]);
 if(r.intermediates.half_width_achieved!==undefined)facts.push(["Semianchura normal",fmt(r.intermediates.half_width_achieved)]);
 if(r.power_limit!==undefined&&r.intermediates.B>0)facts.push(["Límite de potencia normal",fmt(r.power_limit*100)+" %"]);
 el.innerHTML='<p class="eyebrow">RESULTADO DEL ESCENARIO</p><h2>'+esc(r.inputs.scenario_name)+'</h2>'+(r.inputs.demo?'<p class="demo">Ejemplo ilustrativo para comprobación.</p>':"")+'<div class="big">'+esc(main)+'</div><p class="resultlabel">'+esc(labeltext)+'</p><div class="facts">'+facts.map(([k,v])=>'<div class="fact"><span>'+esc(k)+'</span><strong>'+esc(v)+'</strong></div>').join("")+'</div><p class="muted">'+esc(r.method)+' · '+esc(targetNames[r.estimand]||r.estimand)+'</p>'+limitationsHTML(r.module_id,r.limitations)+'<details><summary>Justificación del cálculo</summary><p>'+esc(r.justification)+'</p></details><details><summary>Parámetros y resultados intermedios</summary><pre>'+esc(JSON.stringify({inputs:r.inputs,intermediates:r.intermediates},null,2))+'</pre></details><div class="exportbuttons"><button id="exportjson" class="secondary" type="button">Exportar JSON</button><button id="exporttext" class="secondary" type="button">Exportar justificación</button></div>';
 $("exportjson").onclick=()=>exportToProject("json");
 $("exporttext").onclick=()=>exportToProject("text");
 el.insertAdjacentHTML("beforeend",'<button type="button" id="saveproject" class="secondary">Guardar en la carpeta del proyecto</button><p id="savedstatus" class="muted" role="status"></p>');
 $("saveproject").onclick=()=>exportToProject("save");
 const allowed=["r","D0","D1","p0","p1","sd0","sd1","sd_common","delta","phi","rho2","S","n0","p","residual_var0","residual_var1"].filter(k=>k in r.inputs);
 $("sensitivity").hidden=!allowed.length;options($("sensitivityparameter"),allowed.map(k=>[k,label(k)]));$("sensitivityresult").textContent="";$("exportsensitivity").hidden=true;
}
function loadExample(){
 const p=config.examples.find(p=>p.module_id===mod.id&&p.outcome===$("outcome").value&&p.estimand===$("estimand").value);
 if(!p){$("feedback").textContent="No hay un ejemplo publicado en este prototipo para esa combinación.";return;}
 $("operation").value=p.calculation;renderFields(false);
 for(const k of fieldKeys){$("f_"+k).value=p[k]??defaults[k]??"";$("d_"+k).value=p.provenance[k]?.detail||"Supuesto explícito de demostración: "+(p[k]??defaults[k]??"pendiente");}
 $("scenario").value=p.scenario_name;$("units").value=p.effect_units;
 if($("test")){$("test").value=p.test;$("direction").value=p.direction;$("test").dispatchEvent(new Event("change"));}
 if($("homogeneous"))$("homogeneous").checked=true;
 if($("qdefinition")){$("qdefinition").checked=true;$("pilot").value=p.pilot_definition;}
 if($("pairtarget")){$("pairtarget").value=p.pair_target_justification;$("resampling").value=p.resampling_metadata;}
 $("confirm").checked=false;demo=true;$("demolabel").hidden=false;invalidate();
}
async function init(){
 config=await post("/api/config",null);designChanged();
 $("design").onchange=designChanged;$("outcome").onchange=outcomeChanged;$("estimand").onchange=targetChanged;$("method").onchange=methodChanged;
 $("operation").onchange=()=>{renderFields();invalidate();};
 $("form").addEventListener("input",invalidate);$("form").addEventListener("change",invalidate);
 $("example").onclick=loadExample;
 $("form").onsubmit=async event=>{event.preventDefault();if(!$("form").reportValidity())return;$("feedback").textContent="";$("calculate").disabled=true;const epoch=revision;
 try{const p=buildPayload(),r=await post("/api/calculate",p);if(epoch!==revision)return;lastResult=r;lastPayload=p;renderResult(r);if(r.status!=="ok")$("feedback").textContent=r.message;$("result").focus({preventScroll:true});$("result").scrollIntoView({behavior:"instant",block:"start"});}
 catch(err){if(epoch===revision)$("feedback").textContent="No se pudo contactar con la aplicación local. Comprueba que siga abierta.";}
 finally{$("calculate").disabled=false;}
 };
 $("sensitivityparameter").addEventListener("change",invalidateSensitivity);$("sensitivityvalues").addEventListener("input",invalidateSensitivity);
 $("sensitivitybutton").onclick=async()=>{if(!lastPayload)return;invalidateSensitivity();const values=$("sensitivityvalues").value.split(";").map(t=>t.trim()).filter(Boolean).map(t=>Number(t.replace(",",".")));
 if(!values.length||values.length>5||values.some(v=>!Number.isFinite(v))){$("sensitivityresult").textContent="Introduce entre uno y cinco números finitos, separados por punto y coma.";return;}
 const epoch=revision,senEpoch=sensitivityRevision,request={scenario:lastPayload,parameter:$("sensitivityparameter").value,values};
 $("sensitivitybutton").disabled=true;try{const r=await post("/api/sensitivity",request);if(epoch!==revision||senEpoch!==sensitivityRevision)return;lastSensitivity=r;lastSensitivityRequest=request;
 if(r.status!=="ok")$("sensitivityresult").textContent=r.message;
 else{$("sensitivityresult").innerHTML='<table><thead><tr><th>Valor</th><th>Resultado</th><th>Estado</th></tr></thead><tbody>'+r.rows.map(row=>{const v=row.result;return '<tr><td>'+esc(fmt(row.value))+'</td><td>'+esc(v.status!=="ok"?"—":v.calculation==="power"?fmt(v.power_recalculated*100)+" %":v.calculation==="minimum_detectable_effect"?fmt(v.minimum_detectable_effect):fmt(v.n_analyzable))+'</td><td>'+esc(v.status==="ok"?"Calculado":v.message)+'</td></tr>';}).join("")+'</tbody></table><p class="muted">'+esc(r.note)+'</p>';$("exportsensitivity").hidden=false;}}
 catch(err){if(epoch===revision&&senEpoch===sensitivityRevision)$("sensitivityresult").textContent="No se pudo completar la comparación.";}finally{$("sensitivitybutton").disabled=false;}};
 $("exportsensitivity").onclick=()=>exportToProject("sensitivity");
}
window.jQuery(document).one("shiny:connected",()=>{
 init().catch(()=>{$("feedback").textContent="No se pudo cargar la configuración. Reinicia la aplicación local.";});
});
window.jQuery(document).on("shiny:disconnected",()=>{
 invalidate();$("feedback").textContent="Se perdió la conexión con R. Reinicia la aplicación antes de calcular.";
});
