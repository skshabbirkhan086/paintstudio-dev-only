(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const canvas = $('drawing');
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  const colors = ['#6647ed','#fc6494','#ffaf45','#ffdf53','#70c888','#2cbbcb','#459cff','#1b2440','#ffffff','#161616'];
  let color = colors[0], brushSize = 8, erasing = false, drawing = false;
  let history = [], redoStack = [];
  const status = message => { $('status').textContent = message; };
  const paintWhite = () => {ctx.fillStyle = '#ffffff';ctx.fillRect(0,0,canvas.width,canvas.height);};
  paintWhite();
  function saveSnapshot() {history.push(canvas.toDataURL('image/png'));if(history.length>25)history.shift();redoStack=[];}
  function restore(snapshot) {const img = new Image();img.onload = () => {ctx.clearRect(0,0,canvas.width,canvas.height);ctx.drawImage(img,0,0);};img.src = snapshot;}
  function point(e){const r=canvas.getBoundingClientRect();return {x:(e.clientX-r.left)*canvas.width/r.width,y:(e.clientY-r.top)*canvas.height/r.height};}
  function ink(){return erasing ? '#ffffff' : color;}
  function begin(e){if(e.button!==0 && e.pointerType==='mouse')return;e.preventDefault();saveSnapshot();drawing=true;canvas.setPointerCapture(e.pointerId);const p=point(e);ctx.beginPath();ctx.moveTo(p.x,p.y);ctx.fillStyle=ink();ctx.beginPath();ctx.arc(p.x,p.y,brushSize/2,0,2*Math.PI);ctx.fill();ctx.beginPath();ctx.moveTo(p.x,p.y);}
  function move(e){if(!drawing)return;e.preventDefault();const p=point(e);ctx.lineWidth=brushSize;ctx.lineCap='round';ctx.lineJoin='round';ctx.strokeStyle=ink();ctx.lineTo(p.x,p.y);ctx.stroke();ctx.beginPath();ctx.moveTo(p.x,p.y);}
  function end(){drawing=false;ctx.beginPath();}
  canvas.addEventListener('pointerdown',begin);canvas.addEventListener('pointermove',move);canvas.addEventListener('pointerup',end);canvas.addEventListener('pointercancel',end);canvas.addEventListener('lostpointercapture',end);
  function selectTool(isEraser){erasing=isEraser;$('brush').classList.toggle('selected',!isEraser);$('eraser').classList.toggle('selected',isEraser);$('brush').setAttribute('aria-pressed',String(!isEraser));$('eraser').setAttribute('aria-pressed',String(isEraser));}
  $('brush').onclick=()=>selectTool(false);$('eraser').onclick=()=>selectTool(true);
  const palette=$('palette');
  for(const c of colors){const b=document.createElement('button');b.className='color';b.style.background=c;b.title=c;b.setAttribute('aria-label','Choose '+c);b.onclick=()=>{color=c;$('color-input').value=c;selectTool(false);updatePalette();};palette.appendChild(b);}
  function updatePalette(){for(const b of palette.children)b.classList.toggle('active',b.title===color);}updatePalette();
  $('color-input').oninput=e=>{color=e.target.value;selectTool(false);updatePalette();};
  $('brush-size').oninput=e=>{brushSize=Number(e.target.value);$('brush-label').textContent=brushSize+' px';$('brush-preview').style.width=brushSize+'px';$('brush-preview').style.height=brushSize+'px';};
  $('undo').onclick=()=>{if(!history.length)return;redoStack.push(canvas.toDataURL('image/png'));restore(history.pop());};
  $('redo').onclick=()=>{if(!redoStack.length)return;history.push(canvas.toDataURL('image/png'));restore(redoStack.pop());};
  $('clear').onclick=()=>{if(!confirm('Clear this canvas? You can undo this action.'))return;saveSnapshot();paintWhite();};
  document.addEventListener('keydown',e=>{if((e.ctrlKey||e.metaKey) && e.key.toLowerCase()==='z'){e.preventDefault();(e.shiftKey?$('redo'):$('undo')).click();}if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='y'){e.preventDefault();$('redo').click();}});
  function download(){const a=document.createElement('a');a.href=canvas.toDataURL('image/png');a.download='paintstudio-artwork.png';a.click();}
  $('download').onclick=download;
  const dialog=$('save-dialog');$('save').onclick=()=>dialog.showModal();$('cancel-save').onclick=()=>dialog.close();
  $('save-form').onsubmit=async e=>{e.preventDefault();const button=e.submitter;button.disabled=true;status('Saving artwork…');try{const response=await fetch('/api/paintings/',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({name:$('painting-name').value,dataUrl:canvas.toDataURL('image/png')})});const data=await response.json();if(!response.ok)throw new Error(data.error||'Save failed');dialog.close();$('painting-name').value='';status('Painting saved successfully');await refreshGallery();}catch(err){status('Save failed');alert(err.message);}finally{button.disabled=false;}};
  async function refreshGallery(){let items;try{const response=await fetch('/api/paintings/');if(!response.ok)throw new Error('Could not load gallery');items=await response.json();}catch(err){status(err.message);return;}$('gallery-count').textContent=items.length;const grid=$('gallery-grid');grid.replaceChildren();if(!items.length){const empty=document.createElement('div');empty.className='gallery-empty';empty.innerHTML='<span>🎨</span><strong>Your gallery is waiting</strong>Make your first painting and save it here.';grid.appendChild(empty);return;}for(const item of items){const card=document.createElement('div');card.className='gallery-card';const image=document.createElement('img');image.src=item.imageUrl;image.alt='Saved painting: '+item.name;image.loading='lazy';const info=document.createElement('div');info.className='gallery-info';const title=document.createElement('strong');title.textContent=item.name;const date=document.createElement('p');date.textContent=new Date(item.createdUtc).toLocaleString();const actions=document.createElement('div');actions.className='card-actions';const open=document.createElement('button');open.textContent='Open';open.onclick=()=>openPainting(item.imageUrl);const remove=document.createElement('button');remove.textContent='Delete';remove.className='delete';remove.onclick=()=>deletePainting(item.id,item.name);actions.append(open,remove);info.append(title,date,actions);card.append(image,info);grid.append(card);}}
  async function deletePainting(id,name){if(!confirm(`Delete "${name}" permanently?`))return;const response=await fetch('/api/paintings/'+encodeURIComponent(id),{method:'DELETE'});if(response.ok){status('Painting deleted');refreshGallery();}else alert('Delete failed');}
  function openPainting(url){const img=new Image();img.onload=()=>{saveSnapshot();paintWhite();ctx.drawImage(img,0,0,canvas.width,canvas.height);show('editor');status('Painting opened');};img.onerror=()=>alert('Could not open painting');img.src=url;}
  function show(which){const editor=which==='editor';$('editor-view').hidden=!editor;$('gallery-view').hidden=editor;$('nav-editor').classList.toggle('active',editor);$('nav-gallery').classList.toggle('active',!editor);$('page-heading').textContent=editor?'Canvas Editor':'My Gallery';if(!editor)refreshGallery();}
  $('nav-editor').onclick=()=>show('editor');$('nav-gallery').onclick=()=>show('gallery');$('btn-gallery').onclick=()=>show('gallery');$('btn-new').onclick=()=>{saveSnapshot();paintWhite();show('editor');status('New painting ready');};
  refreshGallery();
})();
