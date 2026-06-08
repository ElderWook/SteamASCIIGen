<script>
  import { onMount } from 'svelte';

  // State
  let imageEl = null;
  let imageName = '';
  let imageWidth = 0;
  let imageHeight = 0;
  
  // Settings
  let asciiWidth = 46;
  let stretchFactor = 1.7;
  let selectedPaletteKey = 'blocks';
  let brightness = 0;
  let contrast = 1.0;
  let invert = false;
  let trimTrailing = true;

  // Output
  let asciiLines = [];
  let fullAsciiText = '';
  let copyAssistantActive = false;
  let copyLineIndex = 0;
  let copySuccessLine = null;
  let copySuccessFull = false;

  const PALETTES = {
    blocks: {
      name: 'Shaded Blocks (░▒▓█)',
      chars: ["　", "░", "▒", "▓", "█"]
    },
    text: {
      name: 'Standard Text (．：＋■)',
      chars: ["　", "．", "：", "＋", "＊", "＃", "％", "＠", "■"]
    },
    silhouette: {
      name: 'Solid Silhouette (■)',
      chars: ["　", "■"]
    },
    braille: {
      name: 'Unicode Braille (⡆⠏⠵)',
      chars: []
    }
  };

  $: activePalette = PALETTES[selectedPaletteKey].chars;

  function handlePaletteChange() {
    if (selectedPaletteKey === 'braille') {
      asciiWidth = 60;
    } else {
      asciiWidth = 46;
    }
  }

  // Reactively regenerate ASCII when settings or image change
  $: if (imageEl && (asciiWidth || stretchFactor || selectedPaletteKey || brightness || contrast || invert || trimTrailing)) {
    generateAscii();
  }


  function handleFileChange(e) {
    const file = e.target.files?.[0];
    if (file) {
      loadImage(file);
    }
  }

  function handleDrop(e) {
    e.preventDefault();
    const file = e.dataTransfer?.files?.[0];
    if (file && file.type.startsWith('image/')) {
      loadImage(file);
    }
  }

  function handleDragOver(e) {
    e.preventDefault();
  }

  function loadImage(file) {
    imageName = file.name;
    const reader = new FileReader();
    reader.onload = (event) => {
      const img = new Image();
      img.onload = () => {
        imageWidth = img.naturalWidth;
        imageHeight = img.naturalHeight;
        imageEl = img;
        copyLineIndex = 0;
      };
      img.src = event.target.result;
    };
    reader.readAsDataURL(file);
  }

  function loadSampleImage() {
    // Generate a default helper heart/star pattern canvas
    const canvas = document.createElement('canvas');
    canvas.width = 200;
    canvas.height = 200;
    const ctx = canvas.getContext('2d');
    
    // Background
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, 200, 200);
    
    // Draw a nice filled heart path in white
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.moveTo(100, 70);
    // Left curve
    ctx.bezierCurveTo(80, 40, 40, 40, 40, 80);
    ctx.bezierCurveTo(40, 120, 80, 150, 100, 175);
    // Right curve
    ctx.bezierCurveTo(120, 150, 160, 120, 160, 80);
    ctx.bezierCurveTo(160, 40, 120, 40, 100, 70);
    ctx.fill();

    const img = new Image();
    img.onload = () => {
      imageName = 'default_heart.png';
      imageWidth = 200;
      imageHeight = 200;
      imageEl = img;
      copyLineIndex = 0;
    };
    img.src = canvas.toDataURL();
  }

  function generateAscii() {
    if (!imageEl) return;
    
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    
    const originalAspect = imageHeight / imageWidth;
    const contrastFactor = (259 * (contrast * 255 + 255)) / (255 * (259 - contrast * 255));
    
    let targetHeight;
    let canvasWidth, canvasHeight;
    
    if (selectedPaletteKey === 'braille') {
      canvasWidth = asciiWidth * 2;
      targetHeight = Math.max(1, Math.round(asciiWidth * originalAspect * stretchFactor));
      canvasHeight = targetHeight * 4;
    } else {
      canvasWidth = asciiWidth;
      targetHeight = Math.max(1, Math.round(asciiWidth * originalAspect * stretchFactor));
      canvasHeight = targetHeight;
    }
    
    canvas.width = canvasWidth;
    canvas.height = canvasHeight;
    
    ctx.drawImage(imageEl, 0, 0, canvasWidth, canvasHeight);
    const imgData = ctx.getImageData(0, 0, canvasWidth, canvasHeight);
    const pixels = imgData.data;
    
    const newLines = [];
    
    if (selectedPaletteKey === 'braille') {
      for (let y = 0; y < targetHeight; y++) {
        let lineChars = [];
        for (let x = 0; x < asciiWidth; x++) {
          let offset = 0;
          
          const isPixelOn = (dx, dy) => {
            const px = x * 2 + dx;
            const py = y * 4 + dy;
            if (px >= canvasWidth || py >= canvasHeight) return false;
            
            const idx = (py * canvasWidth + px) * 4;
            const r = pixels[idx];
            const g = pixels[idx + 1];
            const b = pixels[idx + 2];
            
            let gray = 0.299 * r + 0.587 * g + 0.114 * b;
            gray = contrastFactor * (gray - 128) + 128 + (brightness * 2.55);
            gray = Math.max(0, Math.min(255, gray));
            
            if (invert) {
              gray = 255 - gray;
            }
            
            return gray > 127;
          };

          if (isPixelOn(0, 0)) offset += 1;
          if (isPixelOn(0, 1)) offset += 2;
          if (isPixelOn(0, 2)) offset += 4;
          if (isPixelOn(1, 0)) offset += 8;
          if (isPixelOn(1, 1)) offset += 16;
          if (isPixelOn(1, 2)) offset += 32;
          if (isPixelOn(0, 3)) offset += 64;
          if (isPixelOn(1, 3)) offset += 128;
          
          lineChars.push(String.fromCharCode(0x2800 + offset));
        }
        
        let lineText = lineChars.join('');
        if (trimTrailing) {
          while (lineText.endsWith('　') || lineText.endsWith('⠀')) {
            lineText = lineText.slice(0, -1);
          }
        }
        if (lineText === '') {
          lineText = '⠀'; // Preserve blank line with Braille blank so Steam doesn't collapse it
        }
        newLines.push(lineText);
      }
    } else {
      for (let y = 0; y < targetHeight; y++) {
        let lineChars = [];
        for (let x = 0; x < asciiWidth; x++) {
          const idx = (y * asciiWidth + x) * 4;
          const r = pixels[idx];
          const g = pixels[idx + 1];
          const b = pixels[idx + 2];
          
          let gray = 0.299 * r + 0.587 * g + 0.114 * b;
          gray = contrastFactor * (gray - 128) + 128 + (brightness * 2.55);
          gray = Math.max(0, Math.min(255, gray));
          
          if (invert) {
            gray = 255 - gray;
          }
          
          const charIdx = Math.floor((gray / 256) * activePalette.length);
          lineChars.push(activePalette[charIdx]);
        }
        
        let lineText = lineChars.join('');
        if (trimTrailing) {
          while (lineText.endsWith('　')) {
            lineText = lineText.slice(0, -1);
          }
        }
        if (lineText === '') {
          lineText = '　'; // Preserve blank line with Zenkaku space so Steam doesn't collapse it
        }
        newLines.push(lineText);
      }
    }
    
    asciiLines = newLines;
    fullAsciiText = newLines.join('\n');
  }

  async function copyToClipboard(text) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (err) {
      console.error('Failed to copy to clipboard', err);
      // Fallback
      const textarea = document.createElement('textarea');
      textarea.value = text;
      document.body.appendChild(textarea);
      textarea.select();
      const success = document.execCommand('copy');
      document.body.removeChild(textarea);
      return success;
    }
  }

  function copyFullAscii() {
    copyToClipboard(fullAsciiText).then(() => {
      copySuccessFull = true;
      setTimeout(() => copySuccessFull = false, 2000);
    });
  }

  function copyLine(index) {
    if (index < 0 || index >= asciiLines.length) return;
    
    const lineText = asciiLines[index];
    
    copyToClipboard(lineText).then(() => {
      copySuccessLine = index;
      setTimeout(() => {
        if (copySuccessLine === index) copySuccessLine = null;
      }, 1000);

      // Auto-advance
      if (index < asciiLines.length - 1) {
        copyLineIndex = index + 1;
        scrollToActiveLine(index + 1);
      }
    });
  }

  function scrollToActiveLine(index) {
    const listEl = document.getElementById(`line-item-${index}`);
    if (listEl) {
      listEl.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
  }

  function handleKeydown(e) {
    if (copyAssistantActive) {
      if (e.code === 'Space' || e.code === 'Enter') {
        e.preventDefault();
        copyLine(copyLineIndex);
      } else if (e.code === 'ArrowDown') {
        e.preventDefault();
        if (copyLineIndex < asciiLines.length - 1) {
          copyLineIndex++;
          scrollToActiveLine(copyLineIndex);
        }
      } else if (e.code === 'ArrowUp') {
        e.preventDefault();
        if (copyLineIndex > 0) {
          copyLineIndex--;
          scrollToActiveLine(copyLineIndex);
        }
      }
    }
  }

  onMount(() => {
    loadSampleImage();
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

<div class="min-h-screen pb-16">
  <!-- Top bar header -->
  <header class="border-b border-[#2a475e]/40 bg-[#171a21]/90 backdrop-blur sticky top-0 z-40">
    <div class="max-w-7xl mx-auto px-6 h-16 flex items-center justify-between">
      <div class="flex items-center gap-3">
        <svg viewBox="0 0 24 24" width="24" height="24" class="text-[#66c0f4] fill-[#66c0f4]" aria-hidden="true">
          <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 14.5h-2v-2h2v2zm0-3.5h-2V7h2v6z"/>
        </svg>
        <span class="text-lg font-bold tracking-wide text-white">Steam profile <span class="text-[#66c0f4]">ASCII Art Generator</span></span>
      </div>
      <div class="flex items-center gap-4 text-xs">
        <span class="px-2.5 py-0.5 rounded-full bg-[#1b2838] border border-[#2a475e] text-[#66c0f4] font-medium">Open Source</span>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-6 mt-8 grid grid-cols-1 lg:grid-cols-12 gap-8">
    <!-- Configuration Sidebar -->
    <div class="lg:col-span-4 space-y-6">
      <!-- Image Upload Panel -->
      <div class="glass-panel rounded-2xl p-6 space-y-4">
        <h2 class="text-sm font-semibold uppercase tracking-wider text-[#66c0f4] mb-2">1. Image Input</h2>
        
        <div 
          role="region"
          aria-label="Image drag and drop zone"
          on:drop={handleDrop}
          on:dragover={handleDragOver}
          class="border-2 border-dashed border-[#2a475e] hover:border-[#66c0f4] rounded-xl p-8 text-center cursor-pointer transition-all bg-[#101822]/40 relative group"
        >
          <input type="file" accept="image/*" class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" on:change={handleFileChange} />
          <div class="space-y-2">
            <svg width="32" height="32" class="text-[#2a475e] group-hover:text-[#66c0f4] mx-auto transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            <div class="text-xs text-white font-medium">Drag & drop image here or click to browse</div>
            <div class="text-[10px] text-zinc-500">Supports PNG, JPG, WebP</div>
          </div>
        </div>

        {#if imageEl}
          <div class="flex items-center justify-between p-3 rounded-lg bg-[#101822]/80 border border-[#2a475e]/30 text-xs">
            <div class="min-w-0 flex-1">
              <div class="text-white font-semibold truncate">{imageName}</div>
              <div class="text-zinc-500 text-[10px] mt-0.5">{imageWidth} × {imageHeight} pixels</div>
            </div>
            <button on:click={loadSampleImage} class="text-[10px] text-[#66c0f4] hover:underline ml-4 shrink-0">Use demo image</button>
          </div>
        {/if}
      </div>

      <!-- Settings Panel -->
      <div class="glass-panel rounded-2xl p-6 space-y-5">
        <h2 class="text-sm font-semibold uppercase tracking-wider text-[#66c0f4]">2. Generator Settings</h2>
        
        <!-- Width Configuration -->
        <div class="space-y-1.5">
          <div class="flex justify-between text-xs">
            <label for="slider-width" class="text-zinc-400 font-medium">Showcase Character Width</label>
            <span class="text-white font-mono font-semibold">{asciiWidth} characters</span>
          </div>
          <input 
            id="slider-width"
            type="range" 
            min="20" 
            max="100" 
            bind:value={asciiWidth} 
            class="w-full h-1 bg-[#101822] rounded-lg appearance-none cursor-pointer accent-[#66c0f4]" 
          />
          <div class="flex justify-between text-[9px] text-zinc-500">
            <span>Narrower</span>
            <span>Blocks: 46-47 | Braille: 60-63</span>
            <span>Wider</span>
          </div>
          {#if (selectedPaletteKey === 'braille' && asciiWidth > 60) || (selectedPaletteKey !== 'braille' && asciiWidth > 47)}
            <div class="text-[10px] text-amber-400 font-medium bg-amber-400/10 border border-amber-400/20 px-2.5 py-1.5 rounded-lg flex items-center gap-1.5 mt-2">
              <svg viewBox="0 0 20 20" fill="currentColor" width="14" height="14" class="shrink-0">
                <path fill-rule="evenodd" d="M8.485 2.495c.673-1.167 2.357-1.167 3.03 0l6.28 10.875c.673 1.167-.17 2.625-1.516 2.625H3.72c-1.347 0-2.189-1.458-1.515-2.625L8.485 2.495zM10 5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
              </svg>
              <span>Exceeds recommended width ({selectedPaletteKey === 'braille' ? '60' : '47'} chars). Art may wrap on Steam.</span>
            </div>
          {/if}
        </div>

        <!-- Aspect Stretching Configuration -->
        <div class="space-y-1.5">
          <div class="flex justify-between text-xs">
            <label for="slider-stretch" class="text-zinc-400 font-medium">Vertical Stretch (Anti-Squish)</label>
            <span class="text-white font-mono font-semibold">{stretchFactor.toFixed(1)}x</span>
          </div>
          <input 
            id="slider-stretch"
            type="range" 
            min="1.0" 
            max="2.5" 
            step="0.1" 
            bind:value={stretchFactor} 
            class="w-full h-1 bg-[#101822] rounded-lg appearance-none cursor-pointer accent-[#66c0f4]" 
          />
          <div class="flex justify-between text-[9px] text-zinc-500">
            <span>Square (Squished on Steam)</span>
            <span>Correct Aspect (1.7x)</span>
            <span>Double Tall</span>
          </div>
        </div>

        <!-- Palette Selector -->
        <div class="space-y-1.5">
          <label for="select-palette" class="block text-xs text-zinc-400 font-medium">Zenkaku Character Palette</label>
          <select id="select-palette" bind:value={selectedPaletteKey} on:change={handlePaletteChange} class="w-full text-xs bg-[#101822] border border-[#2a475e]/60 rounded-lg p-2.5 text-white outline-none focus:border-[#66c0f4]">
            {#each Object.entries(PALETTES) as [key, value]}
              <option value={key}>{value.name}</option>
            {/each}
          </select>
        </div>

        <!-- Filters Section -->
        <div class="pt-4 border-t border-[#2a475e]/30 space-y-4">
          <span class="block text-[11px] font-bold uppercase tracking-wider text-zinc-500">Pixel Adjustments</span>
          
          <!-- Brightness -->
          <div class="space-y-1.5">
            <div class="flex justify-between text-xs">
              <label for="slider-brightness" class="text-zinc-400">Brightness</label>
              <span class="text-white font-mono">{brightness > 0 ? '+' : ''}{brightness}</span>
            </div>
            <input 
              id="slider-brightness"
              type="range" 
              min="-100" 
              max="100" 
              bind:value={brightness} 
              class="w-full h-1 bg-[#101822] rounded-lg appearance-none cursor-pointer accent-[#66c0f4]" 
            />
          </div>

          <!-- Contrast -->
          <div class="space-y-1.5">
            <div class="flex justify-between text-xs">
              <label for="slider-contrast" class="text-zinc-400">Contrast</label>
              <span class="text-white font-mono">{contrast.toFixed(1)}x</span>
            </div>
            <input 
              id="slider-contrast"
              type="range" 
              min="0.5" 
              max="2.0" 
              step="0.1" 
              bind:value={contrast} 
              class="w-full h-1 bg-[#101822] rounded-lg appearance-none cursor-pointer accent-[#66c0f4]" 
            />
          </div>

          <!-- Invert & Trim Checkboxes -->
          <div class="flex items-center justify-between pt-2">
            <label class="flex items-center gap-2 text-xs text-zinc-400 cursor-pointer">
              <input type="checkbox" bind:checked={invert} class="rounded border-[#2a475e] bg-[#101822] text-[#66c0f4] focus:ring-0" />
              Invert Colors
            </label>
            <label class="flex items-center gap-2 text-xs text-zinc-400 cursor-pointer">
              <input type="checkbox" bind:checked={trimTrailing} class="rounded border-[#2a475e] bg-[#101822] text-[#66c0f4] focus:ring-0" />
              Trim Trailing Spaces
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- Live Preview & Copy Dashboard -->
    <div class="lg:col-span-8 space-y-6">
      <!-- Header Actions -->
      <div class="flex items-center justify-between flex-wrap gap-4">
        <div>
          <h2 class="text-lg font-semibold text-white">ASCII Output & Showcase Simulator</h2>
          <p class="text-xs text-zinc-400">Real-time simulation rendered in the native Steam browser styles.</p>
        </div>
        <div class="flex gap-2">
          <button on:click={copyFullAscii} class="glow-btn px-4 py-2 rounded-xl text-xs flex items-center gap-2" disabled={!imageEl}>
            {#if copySuccessFull}
              ✓ Copied Full Art!
            {:else}
              Copy Full ASCII Block
            {/if}
          </button>
        </div>
      </div>

      {#if fullAsciiText.length > 8000}
        <div class="text-xs text-rose-400 font-medium bg-rose-400/10 border border-rose-400/20 px-4 py-3 rounded-xl flex items-center gap-2.5">
          <svg viewBox="0 0 20 20" fill="currentColor" width="20" height="20" class="shrink-0 text-rose-400">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-5a.75.75 0 01.75.75v3.5a.75.75 0 01-1.5 0v-3.5A.75.75 0 0110 5zm0 9a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd" />
          </svg>
          <div>
            <strong class="block">Exceeds Steam's 8,000 character limit! (Currently {fullAsciiText.length.toLocaleString()} chars)</strong>
            <span class="text-zinc-400 text-[11px]">Steam's Custom Info Box will display a scrollbar, which breaks the visual rendering. Try reducing the width, lowering the stretch factor, or cropping the image.</span>
          </div>
        </div>
      {/if}

      <!-- Steam Custom Info Box Simulator -->
      <div class="bg-[#171a21] border border-[#2a475e]/40 rounded-2xl p-6 shadow-2xl relative">
        <!-- Steam info box header mock -->
        <div class="flex items-center justify-between pb-3 border-b border-[#2a475e]/30 mb-4 text-xs font-semibold text-[#66c0f4]">
          <span>CUSTOM INFO BOX</span>
          <div class="flex items-center gap-3 text-zinc-500 font-mono">
            <span>{asciiWidth} columns × {asciiLines.length} rows</span>
            <span>•</span>
            <span class={fullAsciiText.length > 8000 ? 'text-rose-400 font-bold' : ''}>
              {fullAsciiText.length.toLocaleString()} / 8,000 chars
            </span>
          </div>
        </div>
        
        <!-- Renders the actual monospace container -->
        {#if imageEl}
          <div class="steam-textbox-simulator">
            <pre class="ascii-container select-all">{fullAsciiText}</pre>
          </div>
        {:else}
          <div class="h-64 flex flex-col items-center justify-center text-center p-8 text-zinc-500 text-xs border border-dashed border-[#2a475e]/40 rounded-xl">
            <span>No image loaded. Please upload a file to begin generating.</span>
          </div>
        {/if}
      </div>

      <!-- Keyboard Copy Assistant Dashboard -->
      {#if imageEl}
        <div class="glass-panel rounded-2xl p-6 space-y-4">
          <div class="flex items-center justify-between flex-wrap gap-3">
            <div class="space-y-0.5">
              <h3 class="text-sm font-semibold text-white">Line-by-Line Copy-Paste Assistant</h3>
              <p class="text-xs text-zinc-400">Pasting large ASCII art in Steam can break lines. Copy and paste them line-by-line instead.</p>
            </div>
            
            <button 
              on:click={() => copyAssistantActive = !copyAssistantActive}
              class="px-3.5 py-1.5 rounded-lg text-xs font-semibold border transition-all {copyAssistantActive ? 'bg-[#66c0f4]/20 border-[#66c0f4] text-[#66c0f4] shadow-md shadow-[#66c0f4]/10' : 'bg-transparent border-[#2a475e] text-zinc-400 hover:text-white hover:border-zinc-400'}"
            >
              {copyAssistantActive ? '⌨️ Keyboard Focus Active' : 'Start Keyboard Mode'}
            </button>
          </div>

          {#if copyAssistantActive}
            <div class="bg-[#101822]/60 rounded-xl p-4 border border-[#66c0f4]/20 text-xs space-y-2">
              <div class="flex items-center justify-between text-zinc-400 font-medium">
                <span>Active Copy line: <strong class="text-[#66c0f4] font-mono">{copyLineIndex + 1} / {asciiLines.length}</strong></span>
                <span class="text-[10px] text-zinc-500">Shortcut: Press <strong class="text-white bg-[#2a475e] px-1.5 py-0.5 rounded font-mono">Space</strong> or <strong class="text-white bg-[#2a475e] px-1.5 py-0.5 rounded font-mono">Enter</strong> to Copy & Advance</span>
              </div>
              
              <div class="flex gap-2">
                <button on:click={() => copyLine(copyLineIndex)} class="glow-btn px-4 py-2.5 rounded-lg text-xs font-bold grow flex items-center justify-center gap-2">
                  {#if copySuccessLine === copyLineIndex}
                    ✓ Copied Line {copyLineIndex + 1}!
                  {:else}
                    Copy Current Line & Advance
                  {/if}
                </button>
                <button 
                  on:click={() => { if (copyLineIndex > 0) { copyLineIndex--; scrollToActiveLine(copyLineIndex); } }} 
                  class="px-3 py-2.5 bg-[#1b2838] border border-[#2a475e] text-white hover:bg-[#203044] rounded-lg"
                  title="Previous Line"
                >
                  ↑
                </button>
                <button 
                  on:click={() => { if (copyLineIndex < asciiLines.length - 1) { copyLineIndex++; scrollToActiveLine(copyLineIndex); } }} 
                  class="px-3 py-2.5 bg-[#1b2838] border border-[#2a475e] text-white hover:bg-[#203044] rounded-lg"
                  title="Next Line"
                >
                  ↓
                </button>
              </div>
            </div>
          {/if}

          <!-- List of lines for copy monitoring -->
          <div class="max-h-60 overflow-y-auto border border-[#2a475e]/30 rounded-xl divide-y divide-[#2a475e]/20 bg-[#101822]/20 pr-1">
            {#each asciiLines as line, idx}
              <div 
                id="line-item-{idx}"
                class="flex items-center justify-between px-4 py-2 text-xs transition-colors {idx === copyLineIndex && copyAssistantActive ? 'bg-[#66c0f4]/10 border-l-2 border-l-[#66c0f4]' : ''} {idx === copySuccessLine ? 'bg-emerald-500/10' : ''}"
              >
                <div class="flex items-center gap-3 min-w-0">
                  <span class="text-[9px] font-mono text-zinc-500 w-6 text-right select-none">{idx + 1}</span>
                  <code class="text-white font-mono truncate select-all">{line === '⠀' || line === '　' ? '　(blank line)' : line}</code>
                </div>
                <button 
                  on:click={() => { copyLineIndex = idx; copyLine(idx); }}
                  class="px-2.5 py-1 rounded bg-[#1b2838] hover:bg-[#25374e] border border-[#2a475e] text-[10px] text-zinc-300 hover:text-white transition-colors"
                >
                  {copySuccessLine === idx ? '✓ Copied' : 'Copy'}
                </button>
              </div>
            {/each}
          </div>
        </div>
      {/if}
    </div>
  </main>
</div>

<style>
  /* Monospace viewer styling targeting Steam's text rendering properties */
  .steam-textbox-simulator {
    background-color: #101822;
    border: 1px solid #2a475e;
    border-radius: 8px;
    padding: 16px;
    overflow-x: auto;
  }

  .ascii-container {
    margin: 0;
    font-family: 'JetBrains Mono', 'Courier New', Courier, monospace;
    font-size: 13px;
    line-height: 1.15;
    letter-spacing: 0.05em;
    color: var(--steam-accent);
    white-space: pre;
    tab-size: 4;
    word-break: keep-all;
    word-wrap: normal;
  }

  /* Focus ring for active copy list items */
  select:focus, input[type="range"]:focus {
    box-shadow: 0 0 10px rgba(102, 192, 244, 0.4);
  }
</style>
