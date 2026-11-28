// إعدادات Supabase المباشرة للمستودع
const SUPABASE_URL = "https://ebbkdhmwaawzxbidjynz.supabase.co";
const SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImViYmtkaG13YWF3enhiaWRqeW56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAxMDI3MTMsImV4cCI6MjA3NTY3ODcxM30.lv_wB9miMcNL3HBg7hXviL3cPaIng2C8x_3rIHzdhF8";

const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// State Variables
let currentUser = null;
let categories = [];
let suppliers = [];
let productsList = [];
let cartItems = [];
let html5QrCode = null;
let isAppDataLoading = false;
let productGalleryUrls = [];
let modalEditGalleryUrls = [];

// On DOM Ready
document.addEventListener("DOMContentLoaded", async () => {
  initTabs();
  initFormListeners();
  initPosScanner();
  initAuthListeners();
  await checkAuthState();
});

// Close modals when pressing Escape
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") {
    closeImageModal();
    closeEditModal();
    closeCameraModal();
    closeProductPhotoModal();
    closeQuickImageModal();
  }
});


// ==========================================
// 🔐 AUTHENTICATION & SESSION MANAGEMENT
// ==========================================

function initAuthListeners() {
  const loginForm = document.getElementById("loginForm");
  if (loginForm) {
    loginForm.addEventListener("submit", handleLogin);
  }

  // Listen to Supabase auth state changes
  supabaseClient.auth.onAuthStateChange(async (event, session) => {
    if (event === "SIGNED_OUT") {
      currentUser = null;
      productsList = [];
      showLoginUI();
    } else if (event === "SIGNED_IN" && session && session.user && !currentUser) {
      await handleUserSession(session.user);
    }
  });
}

function togglePasswordVisibility(e) {
  if (e) {
    if (typeof e.preventDefault === "function") e.preventDefault();
    if (typeof e.stopPropagation === "function") e.stopPropagation();
  }
  const pwdInput = document.getElementById("loginPassword");
  const icon = document.getElementById("togglePasswordIcon");
  if (!pwdInput) return;

  const currentType = pwdInput.getAttribute("type") || pwdInput.type;

  if (currentType === "password") {
    pwdInput.type = "text";
    pwdInput.setAttribute("type", "text");
    if (icon) {
      icon.className = "fa-solid fa-eye-slash";
    }
  } else {
    pwdInput.type = "password";
    pwdInput.setAttribute("type", "password");
    if (icon) {
      icon.className = "fa-solid fa-eye";
    }
  }
}
window.togglePasswordVisibility = togglePasswordVisibility;

async function checkAuthState() {
  try {
    const { data: { session }, error } = await supabaseClient.auth.getSession();
    if (session && session.user) {
      await handleUserSession(session.user);
    } else {
      showLoginUI();
    }
  } catch (err) {
    console.error("خطأ أثناء التحقق من الجلسة:", err);
    showLoginUI();
  }
}

async function handleUserSession(user) {
  try {
    const { data: profile } = await supabaseClient
      .from("profiles")
      .select("id, full_name, email, role")
      .eq("id", user.id)
      .maybeSingle();

    // Verify role: strictly allow admin only
    if (!profile || profile.role !== "admin") {
      await supabaseClient.auth.signOut();
      showLoginUI();
      showLoginAlert("عذراً، هذا الحساب ليس لديه صلاحية الدخول. اللوحة مخصصة لحساب المدير العام فقط (Admin)");
      return;
    }

    currentUser = profile || {
      id: user.id,
      full_name: (user.email || 'مسؤول').split("@")[0],
      email: user.email,
      role: 'admin'
    };

    applyUserUI();
    showAppUI();

    // Load warehouse data once
    if (!isAppDataLoading && productsList.length === 0) {
      isAppDataLoading = true;
      try {
        await loadAppData();
      } finally {
        isAppDataLoading = false;
      }
    }

  } catch (err) {
    console.error("خطأ في معالجة بيانات الحساب:", err);
    showLoginUI();
  }
}

async function loadAppData() {
  try {
    await Promise.all([
      loadCategories(),
      loadSuppliers(),
      loadInventory()
    ]);
  } catch (err) {
    console.error("خطأ في تحميل بيانات التطبيق:", err);
  }
}

async function handleLogin(e) {
  e.preventDefault();
  const emailInput = document.getElementById("loginEmail");
  const passwordInput = document.getElementById("loginPassword");
  const btnSubmit = document.getElementById("btnLoginSubmit");

  const email = emailInput ? emailInput.value.trim() : "";
  const password = passwordInput ? passwordInput.value : "";

  if (!email || !password) {
    showLoginAlert("يرجى إدخال البريد الإلكتروني وكلمة المرور");
    return;
  }

  btnSubmit.disabled = true;
  btnSubmit.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> <span>جاري التحقق...</span>`;

  try {
    const { data, error } = await supabaseClient.auth.signInWithPassword({
      email: email,
      password: password
    });

    if (error) {
      if (error.message.includes("Invalid login credentials")) {
        throw new Error("البريد الإلكتروني أو كلمة المرور غير صحيحة");
      } else if (error.message.includes("Email not confirmed")) {
        throw new Error("يرجى تأكيد البريد الإلكتروني أولاً");
      }
      throw error;
    }

    if (!data || !data.user) {
      throw new Error("لم يتم العثور على بيانات المستخدم");
    }

    await handleUserSession(data.user);

  } catch (err) {
    showLoginAlert(err.message || "حدث خطأ أثناء تسجيل الدخول");
  } finally {
    btnSubmit.disabled = false;
    btnSubmit.innerHTML = `<i class="fa-solid fa-right-to-bracket"></i> <span>تسجيل الدخول</span>`;
  }
}

async function handleLogout() {
  if (!confirm("هل أنت متأكد من رغبتك في تسجيل الخروج؟")) return;
  try {
    await supabaseClient.auth.signOut();
  } catch (err) {
    console.error("خطأ أثناء تسجيل الخروج:", err);
  } finally {
    currentUser = null;
    productsList = [];
    showLoginUI();
    const pwdInput = document.getElementById("loginPassword");
    if (pwdInput) pwdInput.value = "";
    const alertBox = document.getElementById("loginAlert");
    if (alertBox) alertBox.classList.add("hidden");
  }
}

function showAppUI() {
  const loginSection = document.getElementById("loginSection");
  const mainNavbar = document.getElementById("mainNavbar");
  const mainContainer = document.getElementById("mainContainer");
  if (loginSection) loginSection.classList.add("hidden");
  if (mainNavbar) mainNavbar.classList.remove("hidden");
  if (mainContainer) mainContainer.classList.remove("hidden");
  if (document.getElementById("posTab")?.classList.contains("active")) {
    renderPosReceipt();
    loadPosHistory();
  }
}

function showLoginUI() {
  resetPosSession();
  const loginSection = document.getElementById("loginSection");
  const mainNavbar = document.getElementById("mainNavbar");
  const mainContainer = document.getElementById("mainContainer");
  if (loginSection) loginSection.classList.remove("hidden");
  if (mainNavbar) mainNavbar.classList.add("hidden");
  if (mainContainer) mainContainer.classList.add("hidden");
}

function showLoginAlert(message) {
  const alertBox = document.getElementById("loginAlert");
  const alertText = document.getElementById("loginAlertText");
  if (alertBox && alertText) {
    alertText.textContent = message;
    alertBox.classList.remove("hidden");
  } else {
    alert(message);
  }
}

function applyUserUI() {
  const roleEl = document.getElementById("navUserRole");
  if (roleEl) {
    roleEl.textContent = 'أدمن';
  }
}

// ==========================================
// 🖼️ IMAGE PREVIEW HELPERS
// ==========================================
function updateImagePreview(inputId, imgId, placeholderId) {
  const input = document.getElementById(inputId);
  const img = document.getElementById(imgId);
  const placeholder = document.getElementById(placeholderId);

  if (!input || !img || !placeholder) return;

  const url = input.value.trim();

  if (url && (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:image/"))) {
    img.src = url;
    img.classList.remove("hidden");
    placeholder.classList.add("hidden");
  } else {
    img.src = "";
    img.classList.add("hidden");
    placeholder.classList.remove("hidden");
  }
}

function handleImagePreviewError(imgEl, placeholderId) {
  imgEl.src = "";
  imgEl.classList.add("hidden");
  const placeholder = document.getElementById(placeholderId);
  if (placeholder) {
    placeholder.classList.remove("hidden");
  }
}

function openFullImage(inputIdOrUrl) {
  let url = "";
  if (typeof inputIdOrUrl === "string" && (inputIdOrUrl.startsWith("http://") || inputIdOrUrl.startsWith("https://") || inputIdOrUrl.startsWith("data:image/") || inputIdOrUrl.startsWith("blob:"))) {
    url = inputIdOrUrl;
  } else if (typeof inputIdOrUrl === "string") {
    const input = document.getElementById(inputIdOrUrl);
    if (input) url = input.value.trim();
    if (!url) {
      const img = document.getElementById(inputIdOrUrl.replace("Url", "Preview"));
      if (img && !img.classList.contains("hidden") && img.src) url = img.src;
    }
  }

  if (url && (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:image/") || url.startsWith("blob:"))) {
    showFullImageModal(url);
  } else {
    alert("⚠️ لا توجد صورة متاحة للعرض. يرجى إدخال رابط أو رفع صورة صالحة أولاً.");
  }
}

function handlePreviewBoxClick(urlInputId, fileInputId, previewImgId) {
  const urlInput = document.getElementById(urlInputId);
  const img = document.getElementById(previewImgId);
  const url = (urlInput ? urlInput.value.trim() : "") || (img && !img.classList.contains("hidden") ? img.src : "");

  if (url && (url.startsWith("http://") || url.startsWith("https://") || url.startsWith("data:image/") || url.startsWith("blob:"))) {
    showFullImageModal(url);
  } else {
    triggerImageUpload(fileInputId);
  }
}

function showFullImageModal(url) {
  const modal = document.getElementById("imageModal");
  const img = document.getElementById("fullModalImage");
  const link = document.getElementById("fullModalImageLink");

  if (!modal || !img) return;

  img.src = url;
  if (link) link.href = url;

  modal.classList.add("active");
}

function closeImageModal() {
  const modal = document.getElementById("imageModal");
  const img = document.getElementById("fullModalImage");
  if (modal) modal.classList.remove("active");
  if (img) img.src = "";
}

function initTabs() {
  const tabs = document.querySelectorAll(".nav-tab");
  tabs.forEach(tab => {
    tab.addEventListener("click", () => {
      tabs.forEach(t => t.classList.remove("active"));
      document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));

      tab.classList.add("active");
      const targetId = tab.getAttribute("data-tab");
      document.getElementById(targetId).classList.add("active");

      if (targetId === "posTab") {
        renderPosReceipt();
        loadPosHistory();
        const scannerInput = document.getElementById("posBarcodeScanner");
        if (scannerInput) scannerInput.focus();
      } else if (targetId === "fbnLabelsTab") {
        loadFbnItems();
      }
    });
  });
}

// Load Categories from Supabase (Optimized Single DOM Insert)
async function loadCategories() {
  try {
    const { data, error } = await supabaseClient
      .from("categories")
      .select("id, name")
      .order("name", { ascending: true });

    if (error) throw error;
    categories = data || [];

    const categorySelect = document.getElementById("productCategory");
    const filterCategory = document.getElementById("filterCategory");
    const bulkImportCategory = document.getElementById("bulkImportCategory");

    for (const [select, placeholder] of [
      [categorySelect, "اختر القسم..."],
      [filterCategory, "جميع الأقسام"],
      [bulkImportCategory, "اختر القسم الرئيسي..."]
    ]) {
      if (select) select.replaceChildren(new Option(placeholder, ""), ...categories.map(cat => new Option(cat.name, cat.id)));
    }
  } catch (err) {
    console.error("خطأ في جلب الأقسام:", err);
  }
}

// Load Suppliers/Stores from Supabase (Optimized Single DOM Insert)
async function loadSuppliers() {
  try {
    let { data, error } = await supabaseClient
      .from("stores")
      .select("id, name, category, is_active")
      .order("name", { ascending: true });

    if (error || !data || data.length === 0) {
      const fallback = await supabaseClient
        .from("merchants")
        .select("id, name, store_name")
        .order("name", { ascending: true });
      data = (fallback.data || []).map(m => ({ id: m.id, name: m.name || m.store_name || 'مورّد', category: 'تاجر' }));
    }

    suppliers = data || [];

    const supplierSelect = document.getElementById("productSupplier");
    const filterSupplier = document.getElementById("filterSupplier");
    const bulkImportSupplier = document.getElementById("bulkImportSupplier");

    for (const select of [supplierSelect, bulkImportSupplier]) {
      if (!select) continue;
      const options = suppliers.map(sup => {
        const catText = sup.category ? ` (${sup.category})` : '';
        return new Option((sup.name || 'مورّد') + catText, sup.id);
      });
      select.replaceChildren(new Option("اختر المورّد/المتجر...", ""), ...options);
    }
    if (filterSupplier) {
      const options = suppliers.map(sup => new Option(sup.name || 'مورّد', sup.id));
      filterSupplier.replaceChildren(new Option("جميع الموردين/المتاجر", ""), ...options);
    }
  } catch (err) {
    console.error("خطأ في جلب الموردين:", err);
  }
}

const sectionKeywords = {
  "ألبان وأجبان": "جبنة، لبن، حليب، زبادي، رايب، قشطة، زبدة، كيري، عبور لاند، دومتي، جهينة، المراعي، رودس، بريزيدن، لاكتيل",
  "مقرمشات وتسالي": "سوداني، شيبسي، كرانشي، تايجر، فلامنكو، بيك رولز، مكسرات، لب، كري كري، أبو عوف، فشار، ذرة محمصة",
  "حلويات وشوكولاتة": "شوكولاتة، نوتيلا، بسكويت، ويفر، مولتو، هوهوز، توينكيز، حلاوة، مربى، عسل، بسكو مصر، كيك، كرواسون",
  "مشروبات ساخنة": "شاي، قهوة، نسكافيه، بن، كابتشينو، يانسون، نعناع، ليبتون، العروسة، أحمد تي، كاكاو",
  "عصائر ومياه غازية": "عصير، مياه، بيبسي، كوكاكولا، سفن، ميرندا، سبرايت، شويبس، فيروز، حياة، بركة، راني، بيتي",
  "بقالة جافة ومكرونات": "أرز، مكرونة، دقيق، سكر، عدس، فول، لوبيا، فاصوليا، إندومي، نودلز، الضحى، الملكة، إيطاليانو، ريجينا، حوا",
  "زيوت وسمن وصلصات": "زيت، سمنة، سمن، صلصة، كاتشب، مايونيز، خل، طحينة، كريستال، روابي، جنة، عافية، هاينز، كنور، ماجي",
  "معلبات وتونة": "تونة، سردين، بلوبيف، ذرة حلوة، مشروم، فول مدمس، صن شاين، حدائق كاليفورنيا",
  "مخبوزات": "خبز، توست",
  "مجمدات ولحوم": "لحم، لحوم، مجمدات",
  "خضروات وفواكه": "خضروات، فواكه",
  "منظفات وغسيل": "مسحوق، أريال، برسيل، تايد، أوكسي، فيري، بريل، كلور، كلوركس، ديتول، معطر، داوني",
  "ورقيات ومناديل": "مناديل، فاين، زينة، ورق مطبخ، ورق تواليت، فوط صحية، حفاضات، بامبرز، مولفيكس",
  "عناية شخصية": "شامبو، شاور، صابون، معجون أسنان، فرشاة، مزيل عرق، كريم، دوف، لوكس، نيفيا، إيفا، سيجنال، صانسيلك",
  "إلكترونيات وإكسسوارات": "شاحن، كابل، سماعة، موبايل، بطارية، راوتر، فلاشة، باور بانك، جراب",
  "أدوات منزلية": "أدوات منزلية"
};

function normalizeSectionName(text) {
  return String(text || "").normalize("NFKD").toLowerCase()
    .replace(/[\p{M}ـ]/gu, "").replace(/ى/g, "ي").replace(/ة/g, "ه")
    .trim().replace(/\s+/g, " ");
}

function sectionWords(value) {
  return normalizeSectionName(value).replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim().replace(/(^| )ال(?=\p{L})/gu, "$1");
}

const sectionHints = Object.entries(sectionKeywords).map(([name, keywords]) => ({
  displayName: name,
  name: sectionWords(name),
  labels: name.split(/\s+و/).map(sectionWords),
  keywords: keywords.split("، ").map(sectionWords)
}));

function withSectionPhrases(section) {
  const label = sectionWords(section.name);
  const hints = sectionHints.find(group => group.name === label || group.labels.includes(label));
  return { ...section, label, phrases: [label, ...(hints?.keywords || [])].filter(Boolean) };
}

function matchProductSection(productName, sections) {
  const text = " " + sectionWords(productName) + " ";
  let best;
  for (const section of sections) {
    for (const phrase of section.phrases) {
      const index = text.indexOf(" " + phrase + " ");
      if (index < 0) continue;
      const direct = phrase === section.label;
      if (!best || index < best.index || (index === best.index &&
          (phrase.length > best.length || (phrase.length === best.length && direct && !best.direct)))) {
        best = { section, index, length: phrase.length, direct };
      }
    }
  }
  return best?.section;
}

const defaultProductSections = sectionHints.map(group => ({
  name: group.displayName,
  label: group.name,
  phrases: [group.name, ...group.labels, ...group.keywords]
}));

function detectProductSubCategory(productName, storeSections = []) {
  return matchProductSection(productName, storeSections.concat(defaultProductSections));
}

const sectionForms = {};

function autoSelectProductSubCategory(productName, description = '', brand = '', prefix = 'product') {
  const state = sectionForms[prefix];
  if (state.manual) return;
  state.select.value = "";
  for (const field of [productName, description, brand]) {
    const section = matchProductSection(field, state.sections);
    if (section) {
      state.select.value = section.id;
      return;
    }
  }
}

function suggestFormSection(prefix) {
  autoSelectProductSubCategory(
    document.getElementById(prefix + "Name").value,
    document.getElementById(prefix + "Description").value,
    document.getElementById(prefix + "Brand").value, prefix
  );
}

async function fetchStoreSections(storeId) {
  const { data, error } = await supabaseClient.from("store_sections")
    .select("id, name").eq("store_id", storeId).order("display_order").order("id");
  if (error) throw error;
  return data;
}

function loadStoreSectionsForSelect(prefix = "product", product = null) {
  const state = sectionForms[prefix];
  const { select, supplier, notice } = state;
  const storeId = supplier.value;
  const savedId = product?.store_id === storeId ? product.section_id : null;
  const saved = savedId ? { id: savedId, name: product.store_sections?.name } : null;
  clearTimeout(state.timer);
  state.timer = null;
  state.sections = [];
  state.manual = Boolean(saved);
  state.saved = saved;
  state.pending = null;
  state.failed = false;
  notice.textContent = "";
  select.disabled = true;
  select.replaceChildren(new Option(storeId ? "جارٍ تحميل أقسام المتجر…" : "اختر المتجر أولًا", ""));
  if (!storeId) return;

  const pending = fetchStoreSections(storeId).then(rows => {
    if (state.pending !== pending) return;
    const unique = new Map();
    for (const row of rows) {
      const key = normalizeSectionName(row.name);
      if (key && (!unique.has(key) || row.id === savedId)) unique.set(key, row);
    }
    state.sections = Array.from(unique.values(), withSectionPhrases);
    select.replaceChildren(
      new Option(state.sections.length ? "-- اختر أو يُحدد تلقائياً --" : "لا توجد أقسام مسجّلة لهذا المتجر", ""),
      ...state.sections.map(section => new Option(section.name, section.id))
    );
    select.disabled = state.sections.length === 0;
    if (saved) {
      select.value = saved.id;
      if (!select.value) {
        select.value = "";
        notice.textContent = "القسم المحفوظ غير متاح في القائمة. سيبقى مرتبطًا بالسلعة حتى تختار قسمًا آخر.";
      }
    } else {
      suggestFormSection(prefix);
    }
  }).catch(error => {
    if (state.pending !== pending) return;
    state.failed = true;
    select.replaceChildren(new Option("تعذّر تحميل الأقسام", ""));
    notice.textContent = "أعد اختيار المتجر للمحاولة مجددًا.";
    console.warn("تعذّر تحميل أقسام المتجر", error);
  });
  state.pending = pending;
  return pending;
}

function initSectionForm(prefix) {
  const select = document.getElementById(prefix + "SubCategory");
  const supplier = document.getElementById(prefix + "Supplier");
  const notice = document.getElementById(prefix + "SectionNotice");
  const state = sectionForms[prefix] = { select, supplier, notice };
  supplier.addEventListener("change", () => loadStoreSectionsForSelect(prefix));
  select.addEventListener("change", () => {
    state.manual = true;
    state.saved = null;
    notice.textContent = "";
  });
  document.getElementById(prefix + "Name").addEventListener("input", () => {
    clearTimeout(state.timer);
    state.timer = setTimeout(() => {
      state.timer = null;
      suggestFormSection(prefix);
    }, 400);
  });
  loadStoreSectionsForSelect(prefix);
}

async function resolveProductSection(prefix, storeId) {
  const state = sectionForms[prefix];
  const pending = state.pending;
  if (!pending) return null;
  await pending;
  if (pending !== state.pending || storeId !== state.supplier.value) {
    throw new Error("تغيّر المتجر أثناء الحفظ. راجع القسم وأعد الحفظ.");
  }
  if (state.failed) throw new Error("تعذّر تحميل أقسام المتجر. أعد اختيار المتجر قبل الحفظ.");
  if (state.timer) {
    clearTimeout(state.timer);
    state.timer = null;
    suggestFormSection(prefix);
  }
  return state.sections.find(section => section.id === state.select.value) || state.saved;
}

// Load Inventory / Products from Supabase
async function loadInventory() {
  try {
    let { data, error } = await supabaseClient
      .from("products")
      .select("*, categories(name), stores(name), store_sections(name)")
      .order("created_at", { ascending: false })
      .limit(1000);

    if (error) {
      const fallback = await supabaseClient
        .from("products")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(1000);
      if (fallback.error) throw fallback.error;
      data = fallback.data;
    }

    productsList = data || [];
    renderInventoryTable(productsList);
  } catch (err) {
    console.error("خطأ في جلب مخزون السلع:", err);
  }
}

const productUnits = ["قطعة", "علبة", "كيس", "كرتونة", "باكت", "كيلو", "جرام", "لتر", "زجاجة", "عبوة"];
const warehouseQuantityFormat = new Intl.NumberFormat("ar-EG");

function generateProductSku(prefix) {
  const nameInput = document.getElementById(`${prefix}Name`);
  const words = nameInput.value.normalize("NFKC").match(/\p{L}[\p{L}\p{M}]*/gu) || [];
  if (!words.length) {
    alert("اكتب اسم السلعة أولًا لتوليد كود الصنف.");
    nameInput.focus();
    return;
  }
  const initials = words.slice(0, 5).map(word => Array.from(word)[0]).join("").toUpperCase();
  const number = document.getElementById(`${prefix}Barcode`).value.replace(/[^\p{Nd}]/gu, "");
  const suffix = number || String(Math.floor(100000 + Math.random() * 900000));
  document.getElementById(`${prefix}Sku`).value = `${initials}-${suffix}`;
  refreshVariantSkus(prefix);
}

function updateStockPieces(prefix) {
  const stock = document.getElementById(`${prefix}Stock`);
  const pack = document.getElementById(`${prefix}PackSize`);
  const output = document.getElementById(`${prefix}StockPieces`);
  if (!stock.validity.valid || !pack.validity.valid) {
    output.value = "إجمالي القطع: —";
    return;
  }
  const pieces = BigInt(stock.valueAsNumber) * BigInt(pack.valueAsNumber);
  output.value = `إجمالي القطع: ${warehouseQuantityFormat.format(pieces)}`;
}

function populateWarehouseProductFields(prefix, product) {
  const unitSelect = document.getElementById(`${prefix}Unit`);
  unitSelect.querySelector("[data-saved-unit]")?.remove();
  const unit = product.unit || productUnits[0];
  if (!productUnits.includes(unit)) {
    const option = new Option(unit, unit);
    option.dataset.savedUnit = "";
    unitSelect.add(option);
  }
  unitSelect.value = unit;
  document.getElementById(`${prefix}Sku`).value = product.sku || "";
  document.getElementById(`${prefix}ExpiryDate`).value = product.expiry_date || "";
  document.getElementById(`${prefix}PackSize`).value = product.pack_size > 0 ? product.pack_size : 1;
  updateStockPieces(prefix);
}

function warehouseProductFields(prefix) {
  const pack = document.getElementById(`${prefix}PackSize`);
  if (!pack.validity.valid) throw new Error("أدخل معامل تعبئة صحيحًا لا يقل عن 1.");
  return {
    sku: document.getElementById(`${prefix}Sku`).value.trim() || null,
    expiry_date: document.getElementById(`${prefix}ExpiryDate`).value || null,
    unit: document.getElementById(`${prefix}Unit`).value || productUnits[0],
    pack_size: pack.valueAsNumber
  };
}

function renderExpiryBadge(expiryDate, today) {
  const daysLeft = (Date.parse(expiryDate) - today) / 86400000;
  if (!Number.isFinite(daysLeft)) return "";
  const expired = daysLeft < 0;
  const soon = !expired && daysLeft <= 30;
  const badgeClass = expired ? "badge-expiry-expired" : soon ? "badge-expiry-soon" : "badge-expiry-date";
  const label = expired ? "منتهي الصلاحية" : soon ? "ينتهي قريباً" : "الصلاحية";
  const date = escapeHtml(expiryDate);
  return `<span class="meta-tag ${badgeClass}">${label} <time datetime="${date}" dir="ltr">${date}</time></span>`;
}

// Render Inventory Table
function renderInventoryTable(items) {
  const tbody = document.getElementById("inventoryTbody");
  if (!tbody) return;

  if (!items || items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="empty-table-cell">لا توجد سلع مسجلة بالمستودع حالياً</td></tr>`;
    return;
  }

  const today = Date.parse(cairoDateKey());
  tbody.innerHTML = items.map(p => {
    const qty = p.stock_quantity ?? 0;
    const badgeClass = qty > 10 ? "badge-success" : qty > 0 ? "badge-warning" : "badge-danger";
    const qtyText = qty > 0 ? `${qty} ${escapeHtml(p.unit || productUnits[0])}` : "نفذت الكمية";
    const supplierName = p.stores?.name || p.merchants?.name || 'مستودع سوق التل';

    // Extract custom_fields
    const cf = p.custom_fields || {};
    const brand = cf.brand || p.brand || '';
    const size = cf.size || cf.volume || cf.weight || p.size || '';
    const mainBarcode = p.barcode || cf.local_barcode || cf.international_barcode || '';
    const isLocal = mainBarcode.startsWith("200");
    const serial = cf.serial_number || '';
    const color = cf.color || '';
    const warranty = cf.warranty || '';
    const origin = cf.country_of_origin || '';

    return `
      <tr>
        <td>
          ${(() => {
            return `
              ${mainBarcode ? `<div class="${isLocal ? 'badge-local-barcode' : 'meta-tag badge-global-barcode'}" title="الباركود"><i class="fa-solid fa-barcode"></i> <strong>${mainBarcode}</strong> <span class="barcode-type-tag">${isLocal ? 'محلي' : 'دولي / مصنع'}</span></div>` : '<span class="text-muted">بدون باركود</span>'}
            `;
          })()}
        </td>
        <td>
          <div class="product-item-cell">
            <div class="product-thumb-wrapper" onclick="openQuickImageModal('${p.id}')" title="${p.image_url ? 'انقر لتغيير الصورة أو رفع صورة جديدة' : 'انقر لرفع صورة من الجهاز أو لصق رابط'}">
              <div class="product-thumb-placeholder" aria-hidden="true"><i class="fa-solid fa-camera"></i></div>
              ${p.image_url
                ? `<img src="${escapeHtml(p.image_url)}" class="product-thumb" alt="${escapeHtml(p.name || '')}" onerror="this.style.display='none'"><div class="product-thumb-edit-overlay"><i class="fa-solid fa-camera"></i></div>`
                : ''}
            </div>
            <div class="inventory-product-details">
              <strong>${p.name || ''}</strong>
              <div class="product-desc-text">${p.description || ''}</div>
              <div class="meta-tags-container">
                ${p.sku ? `<span class="meta-tag badge-sku" title="كود الصنف بالمخزن">SKU <bdi>${escapeHtml(p.sku)}</bdi></span>` : ''}
                ${renderExpiryBadge(p.expiry_date, today)}
                ${brand ? `<span class="meta-tag badge-brand" title="البراند / الماركة"><i class="fa-solid fa-award"></i> ${brand}</span>` : ''}
                ${size ? `<span class="meta-tag badge-size" title="المقاس / الحجم"><i class="fa-solid fa-ruler-combined"></i> ${size}</span>` : ''}
                ${serial ? `<span class="meta-tag badge-serial" title="السيريال نمبر / الموديل"><i class="fa-solid fa-microchip"></i> SN: ${serial}</span>` : ''}
                ${color ? `<span class="meta-tag badge-size" title="اللون"><i class="fa-solid fa-palette"></i> ${color}</span>` : ''}
                ${warranty ? `<span class="meta-tag badge-brand" title="الضمان"><i class="fa-solid fa-shield-halved"></i> ${warranty}</span>` : ''}
                ${origin ? `<span class="meta-tag badge-global-barcode" title="بلد المنشأ"><i class="fa-solid fa-earth-americas"></i> ${origin}</span>` : ''}
              </div>
            </div>
          </div>
        </td>
        <td>${escapeHtml(p.categories?.name || 'غير محدد')}
          ${p.store_sections?.name ? `<small class="inventory-subcategory">${escapeHtml(p.store_sections.name)}</small>` : ''}
        </td>
        <td>${supplierName}</td>
        <td><strong class="text-danger">${p.cost_price ? p.cost_price + ' ج.م' : '-'}</strong></td>
        <td><strong class="text-primary">${p.price ? p.price + ' ج.م' : '-'}</strong></td>
        <td><span class="badge inventory-stock-badge ${badgeClass}">${qtyText}</span></td>
        <td>
          <div class="table-actions">
            <button type="button" class="btn btn-primary btn-sm" onclick="openEditModal('${p.id}')" title="تعديل كافة بيانات السلعة والباركود والمواصفات">
              <i class="fa-solid fa-pen-to-square"></i> تعديل
            </button>
            <button type="button" class="btn btn-secondary btn-sm" onclick="quickUpdateStock('${p.id}', ${qty})" title="تعديل سريع لكمية المخزون">
              <i class="fa-solid fa-boxes-stacked"></i> المخزون
            </button>
            <button type="button" class="btn btn-outline btn-sm" onclick="previewFbnLabel('${p.id}')" title="طباعة ملصق تتبع حراري FBN لهذه السلعة">
              <i class="fa-solid fa-tags"></i> ملصق FBN
            </button>
            <button type="button" class="btn btn-danger btn-sm" onclick="deleteProduct('${p.id}')" title="حذف السلعة من المستودع">
              <i class="fa-solid fa-trash"></i>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join("");
}

// Filter Inventory Table
function applyInventoryFilter() {
  const searchInput = document.getElementById("searchInventory");
  if (!searchInput) return;

  const query = searchInput.value.trim().toLowerCase();
  const catId = document.getElementById("filterCategory")?.value || "";
  const supId = document.getElementById("filterSupplier")?.value || "";

  const filtered = productsList.filter(p => {
    const cf = p.custom_fields || {};
    const brand = (cf.brand || p.brand || '').toLowerCase();
    const size = (cf.size || p.size || '').toLowerCase();
    const localBarcode = (cf.local_barcode || '').toLowerCase();
    const intBarcode = (cf.international_barcode || '').toLowerCase();
    const serial = (cf.serial_number || '').toLowerCase();
    const name = (p.name || '').toLowerCase();
    const barcode = (p.barcode || '').toLowerCase();

    const matchesQuery = !query ||
      name.includes(query) ||
      (p.store_sections?.name || '').toLowerCase().includes(query) ||
      (p.sku || '').toLowerCase().includes(query) ||
      barcode.includes(query) ||
      localBarcode.includes(query) ||
      brand.includes(query) ||
      size.includes(query) ||
      intBarcode.includes(query) ||
      serial.includes(query);

    const matchesCat = !catId || p.category_id === catId;
    const matchesSup = !supId || p.store_id === supId || p.merchant_id === supId;
    return matchesQuery && matchesCat && matchesSup;
  });

  renderInventoryTable(filtered);
}

// Quick Update Stock
async function quickUpdateStock(productId, currentQty) {
  const newQtyStr = prompt("أدخل الكمية الجديدة بالمخزن لهذا المنتج:", currentQty);
  if (newQtyStr === null) return;
  const newQty = parseInt(newQtyStr, 10);
  if (isNaN(newQty) || newQty < 0) {
    alert("الرجاء إدخال رقم صحيح للكمية");
    return;
  }

  try {
    const updatePayload = {
      stock_quantity: newQty,
      in_stock: newQty > 0
    };

    const { data, error } = await supabaseClient
      .from("products")
      .update(updatePayload)
      .eq("id", productId)
      .select();

    if (error) throw error;

    if (!data || data.length === 0) {
      alert("⚠️ لم تتأثر أي صفوف بالتعديل في الداتابيز. تأكد من إذن التحديث (RLS) أو المعرف الخاص بالمنتج.");
      return;
    }

    // 1. تحديث المصفوفة المحلية فوراً
    const prod = productsList.find(p => p.id === productId);
    if (prod) {
      prod.stock_quantity = newQty;
      prod.in_stock = newQty > 0;
    }

    // 2. إعادة رسم الجدول فوراً بالقيم الجديدة
    renderInventoryTable(productsList);

    // 3. إعادة تحميل البيانات المحدثة من السيرفر
    await loadInventory();

    alert(`✅ تم تحديث كمية المخزون بنجاح إلى: ${newQty} قطعة`);
  } catch (err) {
    alert("❌ فشل تحديث الكمية: " + err.message);
  }
}

// Delete Product
async function deleteProduct(productId) {
  const p = productsList.find(item => item.id === productId);
  const name = p ? p.name : 'السلعة';
  if (!confirm(`هل أنت متأكد من رغبتك في حذف السلعة "${name}" نهائياً من المستودع وقاعدة البيانات؟`)) {
    return;
  }

  try {
    const { error } = await supabaseClient
      .from("products")
      .delete()
      .eq("id", productId);

    if (error) throw error;

    productsList = productsList.filter(item => item.id !== productId);
    applyInventoryFilter();
    alert(`✅ تم حذف السلعة "${name}" بنجاح.`);
  } catch (err) {
    alert("❌ فشل حذف السلعة: " + err.message);
  }
}

// Open Edit Modal for a Product
function openEditModal(productId) {
  const p = productsList.find(item => item.id === productId);
  if (!p) {
    alert("السلعة غير موجودة!");
    return;
  }

  // Populate Categories in modal
  const catSelect = document.getElementById("modalEditCategory");
  if (catSelect) {
    const catOptions = categories.map(cat => `<option value="${cat.id}" ${cat.id === p.category_id ? 'selected' : ''}>${cat.name}</option>`).join("");
    catSelect.innerHTML = '<option value="">اختر القسم...</option>' + catOptions;
  }

  // Populate Suppliers in modal
  const supSelect = document.getElementById("modalEditSupplier");
  if (supSelect) {
    const supOptions = suppliers.map(sup => {
      const isSelected = (sup.id === p.store_id || sup.id === p.merchant_id);
      const catText = sup.category ? ` (${sup.category})` : '';
      return `<option value="${sup.id}" ${isSelected ? 'selected' : ''}>${sup.name || 'مورّد'}${catText}</option>`;
    }).join("");
    supSelect.innerHTML = '<option value="">اختر المورّد/المتجر...</option>' + supOptions;
  }

  const cf = p.custom_fields || {};
  document.getElementById("modalEditProductId").value = p.id;
  document.getElementById("modalEditBarcode").value = p.barcode || cf.local_barcode || cf.international_barcode || "";
  document.getElementById("modalEditName").value = p.name || "";
  document.getElementById("modalEditCostPrice").value = p.cost_price ?? "";
  document.getElementById("modalEditPrice").value = p.price ?? "";
  document.getElementById("modalEditComparePrice").value = p.compare_price ?? "";
  document.getElementById("modalEditStock").value = p.stock_quantity ?? 0;
  populateWarehouseProductFields("modalEdit", p);
  document.getElementById("modalEditInStock").checked = p.in_stock !== false;
  document.getElementById("modalEditIsActive").checked = p.is_active !== false;
  document.getElementById("modalEditImageUrl").value = p.image_url || "";
  document.getElementById("modalEditDescription").value = p.description || "";

  document.getElementById("modalEditBrand").value = cf.brand || p.brand || "";
  loadStoreSectionsForSelect("modalEdit", p);
  document.getElementById("modalEditSize").value = cf.size || cf.volume || cf.weight || p.size || "";
  document.getElementById("modalEditSerialNumber").value = cf.serial_number || "";
  document.getElementById("modalEditColor").value = cf.color || "";
  document.getElementById("modalEditWarranty").value = cf.warranty || "";
  document.getElementById("modalEditOrigin").value = cf.country_of_origin || "";

  updateImagePreview("modalEditImageUrl", "modalEditImagePreview", "modalEditImagePlaceholder");

  // Populate Gallery
  modalEditGalleryUrls = Array.isArray(p.image_urls) ? p.image_urls.filter(u => u && u !== p.image_url) : [];
  renderGalleryGrid("modalEdit");

  // Populate Customer Options (Variant Groups / Custom Fields)
  const modalSpecs = document.getElementById("modalEditSpecsContainer");
  if (modalSpecs) modalSpecs.innerHTML = "";
  const standardKeys = new Set(['brand', 'size', 'color', 'warranty', 'country_of_origin', 'serial_number', 'local_barcode', 'international_barcode', 'fbn_barcode', 'origin', 'volume', 'weight']);

  const loadedOptionKeys = new Set();
  if (Array.isArray(p.variant_groups) && p.variant_groups.length > 0) {
    for (const group of p.variant_groups) {
      if (group && group.name) {
        const values = Array.isArray(group.options) ? group.options.map(o => o.value || o.name).filter(Boolean) : [];
        addCustomSpecRow("modalEdit", group.name, values.join(", "), group.type, true);
        loadedOptionKeys.add(group.name.toLowerCase().trim());
      }
    }
  }

  if (p.custom_fields && typeof p.custom_fields === 'object') {
    for (const [k, v] of Object.entries(p.custom_fields)) {
      if (!standardKeys.has(k) && !loadedOptionKeys.has(k.toLowerCase().trim()) && v !== null && v !== undefined && String(v).trim() !== "") {
        addCustomSpecRow("modalEdit", k, String(v), null, true);
      }
    }
  }

  syncVariantsTable("modalEdit", Array.isArray(p.variants) ? p.variants : []);

  document.getElementById("editProductModal").classList.add("active");
}

function closeEditModal() {
  const modal = document.getElementById("editProductModal");
  if (modal) modal.classList.remove("active");
}

// Save Edit from Modal
async function saveModalEdit() {
  const productId = document.getElementById("modalEditProductId").value;
  const barcode = (document.getElementById("modalEditBarcode")?.value || "").trim();
  const name = document.getElementById("modalEditName").value.trim();
  const categoryId = document.getElementById("modalEditCategory").value;
  const supplierId = document.getElementById("modalEditSupplier").value;
  const costPrice = parseFloat(document.getElementById("modalEditCostPrice").value);
  const price = parseFloat(document.getElementById("modalEditPrice").value);
  const comparePrice = parseFloat(document.getElementById("modalEditComparePrice").value);
  const stockQuantity = parseInt(document.getElementById("modalEditStock").value, 10);
  const inStock = document.getElementById("modalEditInStock").checked;
  const isActive = document.getElementById("modalEditIsActive").checked;
  const imageUrl = document.getElementById("modalEditImageUrl").value.trim();
  const description = document.getElementById("modalEditDescription").value.trim();

  // Additional Fields
  const brand = document.getElementById("modalEditBrand").value.trim();
  const size = document.getElementById("modalEditSize").value.trim();
  const serialNumber = document.getElementById("modalEditSerialNumber").value.trim();
  const color = document.getElementById("modalEditColor").value.trim();
  const warranty = document.getElementById("modalEditWarranty").value.trim();
  const origin = document.getElementById("modalEditOrigin").value.trim();

  if (!barcode || !name || isNaN(price) || isNaN(stockQuantity)) {
    alert("⚠️ الرجاء إدخال رقم الباركود، اسم السلعة، سعر البيع، وكمية المخزون.");
    return;
  }

  // Check if new barcode conflicts with another product
  const conflict = productsList.find(p => {
    if (p.id === productId) return false;
    const cf = p.custom_fields || {};
    return (
      p.barcode === barcode ||
      cf.local_barcode === barcode ||
      cf.international_barcode === barcode ||
      cf.serial_number === barcode
    );
  });

  if (conflict) {
    alert(`⚠️ رقم الباركود (${barcode}) مسجل بالفعل لسلعة أخرى: "${conflict.name}"!\nيرجى استخدام باركود مختلف.`);
    return;
  }

  const btnSave = document.getElementById("btnSaveModalEdit");
  btnSave.disabled = true;
  btnSave.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> <span>جاري حفظ التعديلات...</span>`;

  try {
    const warehouseFields = warehouseProductFields("modalEdit");
    let targetStoreId = supplierId || null;
    if (!targetStoreId && suppliers.length > 0) {
      targetStoreId = suppliers[0].id;
    }

    const existingProd = productsList.find(p => p.id === productId);
    const section = await resolveProductSection("modalEdit", targetStoreId);
    const existingCustomFields = (existingProd && existingProd.custom_fields && typeof existingProd.custom_fields === 'object')
      ? { ...existingProd.custom_fields }
      : {};

    const isLocal = barcode.startsWith("200");
    const variantGroups = getVariantGroupsFromContainer("modalEdit");
    const variants = getVariantsFromContainer("modalEdit", productId);
    const updatedCustomFields = {
      ...existingCustomFields,
      brand: brand || null,
      size: size || null,
      local_barcode: isLocal ? barcode : (existingCustomFields.local_barcode || null),
      international_barcode: !isLocal ? barcode : (existingCustomFields.international_barcode || null),
      serial_number: serialNumber || null,
      color: color || null,
      warranty: warranty || null,
      country_of_origin: origin || null
    };

    // Ensure image is uploaded to cloud storage if it's currently a Base64 data URL
    let finalCloudImageUrl = imageUrl;
    if (finalCloudImageUrl && finalCloudImageUrl.startsWith("data:")) {
      const cleanFileName = `prod_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
      const authUser = (await supabaseClient.auth.getUser())?.data?.user;
      const userId = currentUser?.id || authUser?.id || 'admin';
      const filePath = `${userId}/products/${targetStoreId || 'default'}/${cleanFileName}`;
      const blob = dataURLtoBlob(finalCloudImageUrl);
      const { data: upData, error: upErr } = await supabaseClient.storage
        .from("products")
        .upload(filePath, blob, { contentType: 'image/jpeg', upsert: true });

      if (upErr) {
        throw new Error(`تعذر رفع الصورة إلى سحابة التخزين (${upErr.message}). يرجى التأكد من تشغيل صلاحية مدير المتجر / المسؤول في Supabase Storage.`);
      }

      if (upData) {
        const { data: pubData } = supabaseClient.storage.from("products").getPublicUrl(filePath);
        if (pubData && pubData.publicUrl) {
          finalCloudImageUrl = pubData.publicUrl;
          const inputEl = document.getElementById("modalEditImageUrl");
          if (inputEl) inputEl.value = finalCloudImageUrl;
        }
      }
    }

    const allImages = [finalCloudImageUrl, ...modalEditGalleryUrls].filter(Boolean);
    const uniqueImages = Array.from(new Set(allImages));

    const updatePayload = {
      ...warehouseFields,
      barcode: barcode,
      name: name,
      category_id: categoryId || null,
      store_id: targetStoreId,
      section_id: section?.id ?? null,
      cost_price: isNaN(costPrice) ? null : costPrice,
      price: price,
      compare_price: isNaN(comparePrice) ? null : comparePrice,
      stock_quantity: stockQuantity,
      in_stock: inStock,
      is_active: isActive,
      image_url: finalCloudImageUrl || (uniqueImages.length > 0 ? uniqueImages[0] : null),
      image_urls: uniqueImages.length > 0 ? uniqueImages : null,
      description: description || null,
      custom_fields: updatedCustomFields,
      variant_groups: variantGroups.length > 0 ? variantGroups : null,
      variants: variantsWithPrimaryImage(variants, uniqueImages[0])
    };

    const { error } = await supabaseClient
      .from("products")
      .update(updatePayload)
      .eq("id", productId);

    if (error) throw error;

    // Update local cache
    const prod = productsList.find(p => p.id === productId);
    if (prod) {
      Object.assign(prod, updatePayload);
      prod.store_sections = section ? { name: section.name } : null;
      if (categoryId) {
        const cat = categories.find(c => c.id === categoryId);
        prod.categories = cat ? { name: cat.name } : null;
      }
      if (targetStoreId) {
        const sup = suppliers.find(s => s.id === targetStoreId);
        prod.stores = sup ? { name: sup.name } : null;
      }
    }

    renderInventoryTable(productsList);
    closeEditModal();
    alert(`✅ تم تحديث بيانات السلعة والباركود والمواصفات بنجاح: "${name}"`);
    await loadInventory();
  } catch (err) {
    alert("❌ فشل تحديث السلعة: " + err.message);
  } finally {
    btnSave.disabled = false;
    btnSave.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> <span>حفظ التعديلات على السلعة</span>`;
  }
}

// Start Edit Mode in Tab 1
function startEditModeInTab(productId) {
  const p = productsList.find(item => item.id === productId);
  if (!p) return;

  // Switch to addProductTab
  document.querySelectorAll(".nav-tab").forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));
  const tabBtn = document.querySelector('[data-tab="addProductTab"]');
  if (tabBtn) tabBtn.classList.add("active");
  const tabContent = document.getElementById("addProductTab");
  if (tabContent) tabContent.classList.add("active");

  populateProductForm(p, "product");
  window.scrollTo({ top: 0, behavior: "smooth" });
}

// Cancel Edit Mode in Tab 1
function cancelEditMode() {
  const editingId = document.getElementById("editingProductId");
  if (editingId) editingId.value = "";

  const form = document.getElementById("addProductForm");
  if (form) form.reset();
  populateWarehouseProductFields("product", {});
  loadStoreSectionsForSelect("product");

  const banner = document.getElementById("editModeBanner");
  if (banner) banner.classList.add("hidden");

  const cardTitle = document.getElementById("addProductCardTitle");
  if (cardTitle) cardTitle.innerText = "إدخال بيانات سلعة جديدة وسكان الباركود";

  const btnSave = document.getElementById("btnSaveProduct");
  if (btnSave) {
    btnSave.disabled = false;
    btnSave.innerHTML = '<i class="fa-solid fa-floppy-disk"></i> <span id="btnSaveProductText">حفظ وتسجيل المنتج بالمستودع</span>';
  }

  const btnCancel = document.getElementById("btnCancelEdit");
  if (btnCancel) btnCancel.classList.add("hidden");

  const inStock = document.getElementById("productInStock");
  if (inStock) inStock.checked = true;

  const isActive = document.getElementById("productIsActive");
  if (isActive) isActive.checked = true;

  const barcodeInput = document.getElementById("productBarcode");
  if (barcodeInput) barcodeInput.value = "";

  const brandInput = document.getElementById("productBrand");
  if (brandInput) brandInput.value = "";

  const sizeInput = document.getElementById("productSize");
  if (sizeInput) sizeInput.value = "";

  const serialInput = document.getElementById("productSerialNumber");
  if (serialInput) serialInput.value = "";

  const colorInput = document.getElementById("productColor");
  if (colorInput) colorInput.value = "";

  const warrantyInput = document.getElementById("productWarranty");
  if (warrantyInput) warrantyInput.value = "";

  const originInput = document.getElementById("productOrigin");
  if (originInput) originInput.value = "";

  // Reset Gallery, Options & Variants
  productGalleryUrls = [];
  renderGalleryGrid("product");
  const specsContainer = document.getElementById("productSpecsContainer");
  if (specsContainer) specsContainer.innerHTML = "";
  const variantsBody = document.getElementById("productVariantsTableBody");
  if (variantsBody) variantsBody.innerHTML = "";
  const variantsSection = document.getElementById("productVariantsMatrixSection");
  if (variantsSection) variantsSection.classList.add("hidden");

  updateImagePreview("productImageUrl", "productImagePreview", "productImagePlaceholder");
}


// ============================================================
// Universal Barcode Sanitizer, Classifier & Matcher
// ============================================================

function cleanBarcode(val) {
  if (!val) return "";
  return String(val).trim().replace(/[\r\n\t]/g, "").replace(/\s+/g, "");
}

function isLocalBarcode(code) {
  const clean = cleanBarcode(code);
  if (!clean) return false;
  if (clean.startsWith("ST-")) return true;
  // GS1 restricted in-store distribution prefixes: 20 through 29
  if (/^0?2[0-9]{6,}/.test(clean)) return true;
  // Non-numeric alphanumeric codes are considered local
  if (/[a-zA-Z]/.test(clean)) return true;
  return false;
}

function barcodesMatch(code1, code2) {
  const c1 = cleanBarcode(code1);
  const c2 = cleanBarcode(code2);
  if (!c1 || !c2) return false;
  if (c1 === c2) return true;
  // Compare purely numeric codes ignoring leading zeroes
  if (/^\d+$/.test(c1) && /^\d+$/.test(c2)) {
    return c1.replace(/^0+/, "") === c2.replace(/^0+/, "");
  }
  return false;
}

async function findProductByBarcode(barcodeOrQuery) {
  const code = cleanBarcode(barcodeOrQuery);
  if (!code) return null;

  // 1. Check local cache (productsList) first
  let product = productsList.find(p => {
    const cf = p.custom_fields || {};
    return (
      barcodesMatch(p.barcode, code) ||
      barcodesMatch(cf.local_barcode, code) ||
      barcodesMatch(cf.international_barcode, code) ||
      barcodesMatch(cf.fbn_barcode, code) ||
      barcodesMatch(cf.serial_number, code) ||
      barcodesMatch(p.sku, code)
    );
  });

  if (product) return product;

  // 2. Query Supabase directly
  try {
    const noZeroCode = code.replace(/^0+/, "");
    const { data } = await supabaseClient
      .from("products")
      .select("*, categories(name), stores(name)")
      .or(`barcode.eq.${code},barcode.eq.${noZeroCode},custom_fields->>local_barcode.eq.${code},custom_fields->>international_barcode.eq.${code},custom_fields->>fbn_barcode.eq.${code}`)
      .limit(1)
      .maybeSingle();

    if (data) return data;
  } catch (e) {
    console.warn("Supabase barcode lookup fallback:", e);
  }

  return null;
}

function getUnlinkedProductsOptions() {
  if (!productsList || productsList.length === 0) return "";
  const sorted = [...productsList].sort((a, b) => {
    const aHas = Boolean(a.barcode);
    const bHas = Boolean(b.barcode);
    if (!aHas && bHas) return -1;
    if (aHas && !bHas) return 1;
    return (a.name || "").localeCompare(b.name || "");
  });

  return sorted.map(p => {
    const hasBarcode = Boolean(p.barcode);
    const label = `${p.name} (${p.price || 0} ج.م) ${hasBarcode ? '— [مسجل بباركود آخر]' : '— [بدون باركود]'}`;
    return `<option value="${p.id}">${label}</option>`;
  }).join("");
}

function populateProductForm(prod, prefix = "product", overrideBarcode = "") {
  const cf = prod.custom_fields || {};

  const barcodeInput = document.getElementById(`${prefix}Barcode`);
  const nameInput = document.getElementById(`${prefix}Name`);
  const categorySelect = document.getElementById(`${prefix}Category`);
  const supplierSelect = document.getElementById(`${prefix}Supplier`);
  const costPriceInput = document.getElementById(`${prefix}CostPrice`);
  const priceInput = document.getElementById(`${prefix}Price`);
  const comparePriceInput = document.getElementById(`${prefix}ComparePrice`);
  const stockInput = document.getElementById(`${prefix}Stock`);
  const inStockInput = document.getElementById(`${prefix}InStock`);
  const isActiveInput = document.getElementById(`${prefix}IsActive`);
  const brandInput = document.getElementById(`${prefix}Brand`);
  const sizeInput = document.getElementById(`${prefix}Size`);
  const serialInput = document.getElementById(`${prefix}SerialNumber`);
  const colorInput = document.getElementById(`${prefix}Color`);
  const warrantyInput = document.getElementById(`${prefix}Warranty`);
  const originInput = document.getElementById(`${prefix}Origin`);
  const imageInput = document.getElementById(`${prefix}ImageUrl`);
  const descInput = document.getElementById(`${prefix}Description`);

  const activeBarcode = overrideBarcode || prod.barcode || cf.local_barcode || cf.international_barcode || "";
  if (barcodeInput) barcodeInput.value = activeBarcode;
  if (nameInput) nameInput.value = prod.name || "";
  if (categorySelect && prod.category_id) categorySelect.value = prod.category_id;
  if (supplierSelect) supplierSelect.value = prod.store_id || prod.merchant_id || "";
  if (costPriceInput) costPriceInput.value = prod.cost_price ?? "";
  if (priceInput) priceInput.value = prod.price ?? "";
  if (comparePriceInput) comparePriceInput.value = prod.compare_price ?? "";
  if (stockInput) stockInput.value = prod.stock_quantity ?? 0;
  populateWarehouseProductFields(prefix, prod);
  if (inStockInput) inStockInput.checked = prod.in_stock !== false;
  if (isActiveInput) isActiveInput.checked = prod.is_active !== false;
  if (brandInput) brandInput.value = cf.brand || prod.brand || "";
  if (sizeInput) sizeInput.value = cf.size || cf.volume || cf.weight || prod.size || "";
  if (serialInput) serialInput.value = cf.serial_number || "";
  if (colorInput) colorInput.value = cf.color || "";
  if (warrantyInput) warrantyInput.value = cf.warranty || "";
  if (originInput) originInput.value = cf.country_of_origin || "";
  if (imageInput) imageInput.value = prod.image_url || "";
  if (descInput) descInput.value = prod.description || "";
  loadStoreSectionsForSelect(prefix, prod);

  updateImagePreview(`${prefix}ImageUrl`, `${prefix}ImagePreview`, `${prefix}ImagePlaceholder`);

  // Populate Gallery
  const galleryList = Array.isArray(prod.image_urls) ? prod.image_urls.filter(u => u && u !== prod.image_url) : [];
  if (prefix === "product") {
    productGalleryUrls = [...galleryList];
  } else {
    modalEditGalleryUrls = [...galleryList];
  }
  renderGalleryGrid(prefix);

  // Populate Customer Options (Variant Groups / Custom Fields)
  const specsCont = document.getElementById(`${prefix}SpecsContainer`);
  if (specsCont) specsCont.innerHTML = "";
  const standardKeys = new Set(['brand', 'size', 'color', 'warranty', 'country_of_origin', 'serial_number', 'local_barcode', 'international_barcode', 'fbn_barcode', 'origin', 'volume', 'weight']);

  const loadedOptionKeys = new Set();
  if (Array.isArray(prod.variant_groups) && prod.variant_groups.length > 0) {
    for (const group of prod.variant_groups) {
      if (group && group.name) {
        const values = Array.isArray(group.options) ? group.options.map(o => o.value || o.name).filter(Boolean) : [];
        addCustomSpecRow(prefix, group.name, values.join(", "), group.type, true);
        loadedOptionKeys.add(group.name.toLowerCase().trim());
      }
    }
  }

  if (prod.custom_fields && typeof prod.custom_fields === 'object') {
    for (const [k, v] of Object.entries(prod.custom_fields)) {
      if (!standardKeys.has(k) && !loadedOptionKeys.has(k.toLowerCase().trim()) && v !== null && v !== undefined && String(v).trim() !== "") {
        addCustomSpecRow(prefix, k, String(v), null, true);
      }
    }
  }

  syncVariantsTable(prefix, Array.isArray(prod.variants) ? prod.variants : []);

  if (prefix === "product") {
    const editingIdInput = document.getElementById("editingProductId");
    if (editingIdInput) editingIdInput.value = prod.id;

    const banner = document.getElementById("editModeBanner");
    const bannerText = document.getElementById("editBannerText");
    const cardTitle = document.getElementById("addProductCardTitle");
    const saveBtnText = document.getElementById("btnSaveProductText");
    const cancelBtn = document.getElementById("btnCancelEdit");

    if (banner) banner.classList.remove("hidden");
    if (bannerText) bannerText.innerText = `أنت الآن في وضع تعديل السلعة: "${prod.name}" (الباركود: ${activeBarcode})`;
    if (cardTitle) cardTitle.innerText = "تعديل بيانات السلعة والباركود";
    if (saveBtnText) saveBtnText.innerText = "حفظ التعديلات على السلعة";
    if (cancelBtn) cancelBtn.classList.remove("hidden");
  }
}

function linkBarcodeToExistingProduct(productId, barcode, prefix = "product") {
  if (!productId) return;
  const prod = productsList.find(p => p.id === productId);
  if (!prod) return;

  populateProductForm(prod, prefix, barcode);

  const saveBtnText = document.getElementById("btnSaveProductText");
  if (saveBtnText && prefix === "product") {
    saveBtnText.innerText = `حفظ وربط الباركود بالسلعة ("${prod.name}")`;
  }

  const statusEl = document.getElementById(prefix === "modalEdit" ? "lookupStatusModal" : "lookupStatusMain");
  if (statusEl) {
    statusEl.className = "lookup-status-banner success";
    statusEl.innerHTML = `
      <div class="lookup-status-content">
        <i class="fa-solid fa-circle-check"></i>
        <div>تم اختيار السلعة <strong>"${prod.name}"</strong> بنجاح! اضغط على زر <strong>"حفظ وربط الباركود بالسلعة"</strong> بالأسفل لاعتماد الباركود.</div>
      </div>
    `;
    statusEl.classList.remove("hidden");
  }
}

// Check Barcode when entered in Tab 1
function checkBarcodeForEdit(barcode) {
  if (!barcode) return;
  const editingId = document.getElementById("editingProductId").value;
  const trimmed = barcode.trim();
  const existing = productsList.find(p => {
    const cf = p.custom_fields || {};
    return (
      (p.barcode && p.barcode.trim() === trimmed) ||
      (cf.local_barcode && cf.local_barcode.trim() === trimmed) ||
      (cf.international_barcode && cf.international_barcode.trim() === trimmed) ||
      (cf.serial_number && cf.serial_number.trim() === trimmed)
    );
  });

  if (existing && existing.id !== editingId) {
    if (confirm(`تم العثور على سلعة مسجلة بهذا الباركود/الكود:\n"${existing.name}"\n\nهل ترغب في فتح وضع تعديل هذه السلعة وتعديل بياناتها أو باركودها؟`)) {
      startEditModeInTab(existing.id);
    }
  }
}

// Form Handlers
function initFormListeners() {
  initSectionForm("product");
  initSectionForm("modalEdit");
  for (const prefix of ["product", "modalEdit"]) {
    const refreshPieces = () => updateStockPieces(prefix);
    document.getElementById(`${prefix}Stock`).addEventListener("input", refreshPieces);
    document.getElementById(`${prefix}PackSize`).addEventListener("input", refreshPieces);
    for (const field of ["Sku", "Barcode"]) {
      document.getElementById(`${prefix}${field}`).addEventListener("input", () => refreshVariantSkus(prefix));
    }
    refreshPieces();
  }
  const form = document.getElementById("addProductForm");
  if (form) {
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      await saveProduct();
    });
  }

  const modalEditForm = document.getElementById("editProductModalForm");
  if (modalEditForm) {
    modalEditForm.addEventListener("submit", async (e) => {
      e.preventDefault();
      await saveModalEdit();
    });
  }

  const barcodeInput = document.getElementById("productBarcode");
  if (barcodeInput) {
    barcodeInput.addEventListener("change", () => {
      checkBarcodeForEdit(barcodeInput.value.trim());
    });
    barcodeInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        lookupBarcodeOnline("productBarcode", false);
      }
    });
  }

  const modalBarcodeInput = document.getElementById("modalEditBarcode");
  if (modalBarcodeInput) {
    modalBarcodeInput.addEventListener("keypress", (e) => {
      if (e.key === "Enter") {
        e.preventDefault();
        lookupBarcodeOnline("modalEditBarcode", true);
      }
    });
  }

  const imageUrlInput = document.getElementById("productImageUrl");
  if (imageUrlInput) {
    imageUrlInput.addEventListener("input", () => {
      updateImagePreview("productImageUrl", "productImagePreview", "productImagePlaceholder");
    });
    imageUrlInput.addEventListener("change", () => {
      updateImagePreview("productImageUrl", "productImagePreview", "productImagePlaceholder");
    });
  }

  const imgPreview = document.getElementById("productImagePreview");
  if (imgPreview) {
    imgPreview.addEventListener("error", () => {
      handleImagePreviewError(imgPreview, "productImagePlaceholder");
    });
  }

  const modalImageUrlInput = document.getElementById("modalEditImageUrl");
  if (modalImageUrlInput) {
    modalImageUrlInput.addEventListener("input", () => {
      updateImagePreview("modalEditImageUrl", "modalEditImagePreview", "modalEditImagePlaceholder");
    });
    modalImageUrlInput.addEventListener("change", () => {
      updateImagePreview("modalEditImageUrl", "modalEditImagePreview", "modalEditImagePlaceholder");
    });
  }

  const modalImgPreview = document.getElementById("modalEditImagePreview");
  if (modalImgPreview) {
    modalImgPreview.addEventListener("error", () => {
      handleImagePreviewError(modalImgPreview, "modalEditImagePlaceholder");
    });
  }

  const searchInventory = document.getElementById("searchInventory");
  if (searchInventory) searchInventory.addEventListener("input", applyInventoryFilter);

  const filterCategory = document.getElementById("filterCategory");
  if (filterCategory) filterCategory.addEventListener("change", applyInventoryFilter);

  const filterSupplier = document.getElementById("filterSupplier");
  if (filterSupplier) filterSupplier.addEventListener("change", applyInventoryFilter);

  // Smart Auto-Fill: listen to product name input
  const productNameInput = document.getElementById("productName");
  if (productNameInput) {
    productNameInput.addEventListener("input", () => smartAutoFill(productNameInput.value, "product"));
    productNameInput.addEventListener("paste", () => setTimeout(() => smartAutoFill(productNameInput.value, "product"), 50));
  }
}

// Save Product to Supabase (Add or Edit)
async function saveProduct() {
  const editingId = document.getElementById("editingProductId").value.trim();
  const barcode = (document.getElementById("productBarcode")?.value || "").trim();
  const name = document.getElementById("productName").value.trim();
  const categoryId = document.getElementById("productCategory").value;
  const supplierId = document.getElementById("productSupplier").value;
  const costPrice = parseFloat(document.getElementById("productCostPrice").value);
  const price = parseFloat(document.getElementById("productPrice").value);
  const comparePrice = parseFloat(document.getElementById("productComparePrice").value);
  const stockQuantity = parseInt(document.getElementById("productStock").value, 10);
  const inStock = document.getElementById("productInStock").checked;
  const isActive = document.getElementById("productIsActive").checked;
  const description = document.getElementById("productDescription").value.trim();
  const imageUrl = document.getElementById("productImageUrl").value.trim();

  // Additional Fields
  const brand = document.getElementById("productBrand").value.trim();
  const size = document.getElementById("productSize").value.trim();
  const serialNumber = document.getElementById("productSerialNumber").value.trim();
  const color = document.getElementById("productColor").value.trim();
  const warranty = document.getElementById("productWarranty").value.trim();
  const origin = document.getElementById("productOrigin").value.trim();

  if (!barcode || !name || isNaN(price) || isNaN(stockQuantity)) {
    alert("⚠️ الرجاء إدخال رقم الباركود، اسم السلعة، سعر البيع، وكمية المخزون.");
    return;
  }

  // Validate barcode conflict with other products
  const conflict = productsList.find(p => {
    if (p.id === editingId) return false;
    const cf = p.custom_fields || {};
    return (
      p.barcode === barcode ||
      cf.local_barcode === barcode ||
      cf.international_barcode === barcode ||
      cf.serial_number === barcode
    );
  });

  if (conflict) {
    alert(`⚠️ رقم الباركود (${barcode}) مسجل بالفعل لسلعة أخرى: "${conflict.name}"!\nيرجى استخدام باركود مختلف.`);
    return;
  }

  const btnSave = document.getElementById("btnSaveProduct");
  if (btnSave) {
    btnSave.disabled = true;
    btnSave.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> <span id="btnSaveProductText">جاري الحفظ والتسجيل...</span>';
  }

  try {
    let targetStoreId = supplierId || null;
    if (!targetStoreId && suppliers.length > 0) {
      targetStoreId = suppliers[0].id;
    }

    let existingCustomFields = {};
    const warehouseFields = warehouseProductFields("product");
    const section = await resolveProductSection("product", targetStoreId);
    if (editingId) {
      const existingProd = productsList.find(p => p.id === editingId);
      if (existingProd && existingProd.custom_fields && typeof existingProd.custom_fields === 'object') {
        existingCustomFields = { ...existingProd.custom_fields };
      }
    }

    const isLocal = barcode.startsWith("200");
    const variantGroups = getVariantGroupsFromContainer("product");
    const variants = getVariantsFromContainer("product", editingId || "");
    const updatedCustomFields = {
      ...existingCustomFields,
      brand: brand || null,
      size: size || null,
      local_barcode: isLocal ? barcode : (existingCustomFields.local_barcode || null),
      international_barcode: !isLocal ? barcode : (existingCustomFields.international_barcode || null),
      serial_number: serialNumber || null,
      color: color || null,
      warranty: warranty || null,
      country_of_origin: origin || null
    };

    // Ensure image is uploaded to cloud storage if it's currently a Base64 data URL
    let finalCloudImageUrl = imageUrl;
    if (finalCloudImageUrl && finalCloudImageUrl.startsWith("data:")) {
      const cleanFileName = `prod_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
      const authUser = (await supabaseClient.auth.getUser())?.data?.user;
      const userId = currentUser?.id || authUser?.id || 'admin';
      const filePath = `${userId}/products/${targetStoreId || 'default'}/${cleanFileName}`;
      const blob = dataURLtoBlob(finalCloudImageUrl);
      const { data: upData, error: upErr } = await supabaseClient.storage
        .from("products")
        .upload(filePath, blob, { contentType: 'image/jpeg', upsert: true });

      if (upErr) {
        throw new Error(`تعذر رفع الصورة إلى سحابة التخزين (${upErr.message}). يرجى التأكد من تشغيل صلاحية مدير المتجر / المسؤول في Supabase Storage.`);
      }

      if (upData) {
        const { data: pubData } = supabaseClient.storage.from("products").getPublicUrl(filePath);
        if (pubData && pubData.publicUrl) {
          finalCloudImageUrl = pubData.publicUrl;
          const inputEl = document.getElementById("productImageUrl");
          if (inputEl) inputEl.value = finalCloudImageUrl;
        }
      }
    }

    const allImages = [finalCloudImageUrl, ...productGalleryUrls].filter(Boolean);
    const uniqueImages = Array.from(new Set(allImages));

    const productPayload = {
      ...warehouseFields,
      barcode: barcode,
      name: name,
      category_id: categoryId || null,
      store_id: targetStoreId,
      section_id: section?.id ?? null,
      cost_price: isNaN(costPrice) ? null : costPrice,
      price: price,
      compare_price: isNaN(comparePrice) ? null : comparePrice,
      stock_quantity: stockQuantity,
      in_stock: inStock,
      is_active: isActive,
      description: description || null,
      image_url: finalCloudImageUrl || (uniqueImages.length > 0 ? uniqueImages[0] : null),
      image_urls: uniqueImages.length > 0 ? uniqueImages : null,
      custom_fields: updatedCustomFields,
      variant_groups: variantGroups.length > 0 ? variantGroups : null,
      variants: variantsWithPrimaryImage(variants, uniqueImages[0])
    };

    let res;
    if (editingId) {
      res = await supabaseClient
        .from("products")
        .update(productPayload)
        .eq("id", editingId);
    } else {
      const { data: existing } = await supabaseClient
        .from("products")
        .select("id, name")
        .eq("barcode", barcode)
        .maybeSingle();

      if (existing) {
        if (!confirm(`السلعة مسجلة بالفعل بهذا الباركود ("${existing.name}")، هل تريد تحديث بياناتها؟`)) {
          btnSave.disabled = false;
          btnSave.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> <span id="btnSaveProductText">حفظ وتسجيل المنتج بالمستودع</span>`;
          return;
        }
        res = await supabaseClient
          .from("products")
          .update(productPayload)
          .eq("id", existing.id);
      } else {
        res = await supabaseClient
          .from("products")
          .insert(productPayload);
      }
    }

    if (res.error) throw res.error;

    alert(editingId ? "✅ تم حفظ تعديلات السلعة والباركود بنجاح!" : "✅ تم حفظ السلعة بنجاح وربطها بالمستودع والمورّد!");
    cancelEditMode();
    await loadInventory();
  } catch (err) {
    alert("❌ حدث خطأ أثناء الحفظ: " + err.message);
  } finally {
    if (btnSave) {
      btnSave.disabled = false;
      btnSave.innerHTML = '<i class="fa-solid fa-floppy-disk"></i> <span id="btnSaveProductText">حفظ وتسجيل المنتج بالمستودع</span>';
    }
  }
}

const posDayFormatter = new Intl.DateTimeFormat("en", {
  timeZone: "Africa/Cairo", year: "numeric", month: "2-digit", day: "2-digit"
});
const posTimeFormatter = new Intl.DateTimeFormat("ar-EG", {
  timeZone: "Africa/Cairo", dateStyle: "short", timeStyle: "short"
});

let pendingPosCheckout = null;
let posCheckoutBusy = false;
let posHistoryRequest = null;
let posHistoryRows = [];
let posHistoryDay = "";
const posReturnsInProgress = new Set();

function cairoDateKey(date = new Date()) {
  const parts = Object.fromEntries(posDayFormatter.formatToParts(date).map(({ type, value }) => [type, value]));
  return `${parts.year}-${parts.month}-${parts.day}`;
}

function formatPosMoney(amount) {
  return `${Number(amount || 0).toFixed(2)} ج.م`;
}

function readPendingPosCheckout() {
  const userId = currentUser?.id;
  if (!userId) return null;
  if (pendingPosCheckout?.userId === userId) return pendingPosCheckout.request;
  try {
    return JSON.parse(sessionStorage.getItem("pendingPosCheckout:" + userId));
  } catch {
    return null;
  }
}

function setPendingPosCheckout(userId, request) {
  pendingPosCheckout = request ? { userId, request } : null;
  try {
    if (request) sessionStorage.setItem("pendingPosCheckout:" + userId, JSON.stringify(request));
    else sessionStorage.removeItem("pendingPosCheckout:" + userId);
  } catch {
    // In-memory request remains available when browser storage is unavailable.
  }
}

function resetPosSession() {
  cartItems = [];
  posHistoryRows = [];
  posHistoryRequest = null;
  posHistoryDay = "";
  const checkoutStatus = document.getElementById("posCheckoutStatus");
  if (checkoutStatus) checkoutStatus.textContent = "";
  renderPosReceipt();
  renderPosHistory();
}

function isPosCartLocked() {
  return posCheckoutBusy || Boolean(readPendingPosCheckout());
}

// Barcode Scanner Listener for POS
function initPosScanner() {
  document.getElementById("btnRefreshPosHistory").addEventListener("click", loadPosHistory);
  document.getElementById("btnPrintPosShift").addEventListener("click", printPosShift);
  document.getElementById("posHistoryRows").addEventListener("click", handlePosHistoryAction);
  window.addEventListener("afterprint", () => document.body.classList.remove("pos-printing"));
  renderPosReceipt();
  renderPosHistory();
  const scannerInput = document.getElementById("posBarcodeScanner");
  if (!scannerInput) return;

  // High speed barcode scanner listener (triggers on Enter)
  scannerInput.addEventListener("keypress", async (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      const code = scannerInput.value.trim();
      if (code) {
        scannerInput.value = "";
        await scanAndAddToCart(code);
      }
    }
  });
}

// Add scanned product to POS receipt
async function scanAndAddToCart(barcodeOrQuery) {
  const cashierId = currentUser?.id;
  if (!cashierId || isPosCartLocked()) return;
  const code = cleanBarcode(barcodeOrQuery);
  if (!code) return;

  // 1. Flexible Barcode Matcher (local cache & Supabase)
  let product = await findProductByBarcode(code);

  // 2. Fallback search by Product Name in local cache
  if (!product) {
    const lower = code.toLowerCase();
    product = productsList.find(p => p.name && p.name.toLowerCase().includes(lower));
  }

  // 3. Fallback search by Name in Supabase
  if (!product) {
    try {
      const { data } = await supabaseClient
        .from("products")
        .select("*, categories(name)")
        .ilike("name", `%${code}%`)
        .limit(1)
        .maybeSingle();

      if (data) product = data;
    } catch (e) {
      console.warn("POS name lookup fallback:", e);
    }
  }

  if (currentUser?.id !== cashierId || isPosCartLocked()) return;
  if (!product) {
    showPosBarcodeUnregisteredDialog(code);
    return;
  }

  addPosProduct(product);
}

function addPosProduct(product) {
  const currentInCart = cartItems.find(i => i.product.id === product.id);
  const qtyInCart = currentInCart ? currentInCart.quantity : 0;

  const stock = product.stock_quantity ?? 0;
  if (qtyInCart >= stock) {
    alert(`الكمية المتاحة بالمخزن ${stock}`);
    return false;
  }

  if (currentInCart) {
    currentInCart.quantity += 1;
  } else {
    cartItems.push({ product: product, quantity: 1 });
  }

  renderPosReceipt();
  return true;
}

// Modal for Barcodes not found in POS
function showPosBarcodeUnregisteredDialog(barcode) {
  let modal = document.getElementById("posUnregisteredModal");
  if (!modal) {
    modal = document.createElement("div");
    modal.id = "posUnregisteredModal";
    modal.className = "modal active";
    document.body.appendChild(modal);
  }

  const isLocal = isLocalBarcode(barcode);
  const unlinkedOptionsHtml = getUnlinkedProductsOptions();

  modal.className = "modal active";
  modal.innerHTML = `
    <div class="modal-content modal-md">
      <div class="modal-header">
        <h3 class="modal-title text-warning">
          <i class="fa-solid fa-triangle-exclamation"></i>
          <span>باركود غير مسجل بالمستودع</span>
        </h3>
        <button type="button" class="btn btn-danger btn-modal-close" onclick="closePosUnregisteredModal()">✕</button>
      </div>
      <div class="modal-body" style="padding: 1.5rem; text-align: right;">
        <p style="font-size: 0.95rem; margin-bottom: 1rem; color: #1e293b;">
          تم قراءة الباركود ${isLocal ? '<strong>المحلي</strong>' : '<strong>الدولي</strong>'}:
          <strong style="font-family: monospace; font-size: 1.1rem; color: var(--primary);">${escapeHtml(barcode)}</strong>
          <br>
          <span style="color: #64748b; font-size: 0.88rem;">هذا الباركود غير مسجل لأي سلعة حالياً في مستودعك.</span>
        </p>

        ${unlinkedOptionsHtml ? `
          <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 1rem; margin-bottom: 1rem;">
            <label style="font-weight: 700; display: block; margin-bottom: 6px; font-size: 0.88rem; color: #334155;">
              <i class="fa-solid fa-link"></i> خيار سريع: ربط هذا الباركود بسلعة موجودة وإضافتها للرسيد فوراً:
            </label>
            <select id="posLinkSelect" style="width: 100%; padding: 8px 10px; border-radius: 6px; border: 1.5px solid var(--primary); font-family: inherit; font-size: 0.88rem; font-weight: 600;">
              <option value="">-- اضغط هنا لاختيار السلعة --</option>
              ${unlinkedOptionsHtml}
            </select>
            <button type="button" class="btn btn-success" style="width: 100%; margin-top: 8px;" data-pos-link>
              <i class="fa-solid fa-check"></i> ربط الباركود وحفظه وإضافة السلعة للرسيد الآن
            </button>
          </div>
        ` : ''}

        <div style="text-align: center; border-top: 1px dashed #cbd5e1; padding-top: 1rem; display: flex; justify-content: center; gap: 8px;">
          <button type="button" class="btn btn-primary" data-pos-add>
            <i class="fa-solid fa-plus"></i> إضافة سلعة جديدة بهذا الباركود بالمستودع
          </button>
          <button type="button" class="btn btn-secondary" onclick="closePosUnregisteredModal()">
            إلغاء
          </button>
        </div>
      </div>
    </div>
  `;
  modal.querySelector("[data-pos-link]")?.addEventListener("click", () => posQuickLinkAndAdd(barcode));
  modal.querySelector("[data-pos-add]").addEventListener("click", () => posGoToAddProduct(barcode));
}

function closePosUnregisteredModal() {
  const modal = document.getElementById("posUnregisteredModal");
  if (modal) modal.classList.remove("active");
}

async function posQuickLinkAndAdd(barcode) {
  const cashierId = currentUser?.id;
  if (!cashierId || isPosCartLocked()) return;
  const select = document.getElementById("posLinkSelect");
  const pId = select?.value;
  if (!pId) {
    alert("الرجاء اختيار سلعة من القائمة لربط الباركود بها.");
    return;
  }

  const prod = productsList.find(p => p.id === pId);
  if (!prod) return;

  try {
    const isLocal = isLocalBarcode(barcode);
    const existingCf = prod.custom_fields || {};
    const updatedCf = {
      ...existingCf,
      local_barcode: isLocal ? barcode : (existingCf.local_barcode || null),
      international_barcode: !isLocal ? barcode : (existingCf.international_barcode || null)
    };

    const { error } = await supabaseClient
      .from("products")
      .update({
        barcode: barcode,
        custom_fields: updatedCf
      })
      .eq("id", pId);

    if (error) throw error;

    prod.barcode = barcode;
    prod.custom_fields = updatedCf;

    closePosUnregisteredModal();
    if (currentUser?.id === cashierId && !isPosCartLocked()) addPosProduct(prod);
  } catch (err) {
    alert("❌ تعذر حفظ الباركود: " + err.message);
  }
}

function posGoToAddProduct(barcode) {
  closePosUnregisteredModal();
  const tabs = document.querySelectorAll(".nav-tab");
  tabs.forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab-content").forEach(c => c.classList.remove("active"));

  const addTabBtn = document.querySelector('[data-tab="addProductTab"]');
  if (addTabBtn) addTabBtn.classList.add("active");
  const addTab = document.getElementById("addProductTab");
  if (addTab) addTab.classList.add("active");

  const barcodeInput = document.getElementById("productBarcode");
  if (barcodeInput) {
    barcodeInput.value = barcode;
    lookupBarcodeOnline("productBarcode", false);
  }
}

// Render POS Receipt
function renderPosReceipt() {
  const container = document.getElementById("posReceiptItems");
  if (!container) return;
  const pending = readPendingPosCheckout();
  const locked = posCheckoutBusy || Boolean(pending);
  const checkoutButton = document.getElementById("btnCheckoutPos");
  const checkoutLabel = document.getElementById("posCheckoutLabel");
  checkoutButton.disabled = posCheckoutBusy || (!pending && cartItems.length === 0);
  checkoutLabel.textContent = posCheckoutBusy ? "جارٍ إتمام العملية…" :
    pending ? "التحقق من الفاتورة وإعادة المحاولة" : "إتمام العملية وطباعة الفاتورة";
  document.getElementById("posBarcodeScanner").disabled = locked;
  document.getElementById("btnScanPosCamera").disabled = locked;

  let total = 0;
  container.innerHTML = cartItems.map((item, index) => {
    const itemTotal = item.product.price * item.quantity;
    total += itemTotal;

    return `
      <div class="receipt-item">
        <div>
          <strong>${escapeHtml(item.product.name)}</strong>
          <div class="text-muted">${formatPosMoney(item.product.price)} × ${item.quantity} ${escapeHtml(item.product.unit || "قطعة")}</div>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <button type="button" class="btn btn-secondary btn-sm" onclick="updateCartQty(${index}, -1)" aria-label="إنقاص الكمية" ${locked ? "disabled" : ""}>−</button>
          <span>${item.quantity}</span>
          <button type="button" class="btn btn-secondary btn-sm" onclick="updateCartQty(${index}, 1)" aria-label="زيادة الكمية" ${locked ? "disabled" : ""}>+</button>
          <strong class="text-primary">${formatPosMoney(itemTotal)}</strong>
        </div>
      </div>
    `;
  }).join("") || `<p class="pos-status text-center">${pending
    ? "توجد فاتورة معلّقة. اضغط زر التحقق لإكمالها."
    : "امسح باركود السلعة لإضافتها للفاتورة."}</p>`;

  document.getElementById("posTotalAmount").textContent = pending && !cartItems.length ? "—" : formatPosMoney(total);
}

function updateCartQty(index, change) {
  if (isPosCartLocked() || index < 0 || index >= cartItems.length) return;
  const item = cartItems[index];
  const quantity = item.quantity + change;
  if (quantity > (item.product.stock_quantity ?? 0)) {
    alert(`الكمية المتاحة بالمخزن ${item.product.stock_quantity ?? 0}`);
    return;
  }
  if (quantity <= 0) cartItems.splice(index, 1);
  else item.quantity = quantity;
  renderPosReceipt();
}

async function checkoutPosSale() {
  const cashierId = currentUser?.id;
  if (!cashierId || posCheckoutBusy) return;
  let request = readPendingPosCheckout();
  if (!request && !cartItems.length) return;
  const status = document.getElementById("posCheckoutStatus");
  if (!request) {
    request = {
      id: crypto.randomUUID(),
      items: cartItems.map(({ product, quantity }) => ({ product_id: product.id, quantity })),
      uncertain: false
    };
  }
  // A reload while the request is in flight must resume the same sale.
  setPendingPosCheckout(cashierId, { ...request, uncertain: true });

  posCheckoutBusy = true;
  status.textContent = "جارٍ تسجيل الفاتورة وتحديث المخزون…";
  renderPosReceipt();

  let savedSale;
  try {
    const result = await supabaseClient.rpc("checkout_pos_sale", {
      p_items: request.items,
      p_request_id: request.id
    });
    if (result.error) {
      // A server or transport failure can occur after a committed sale.
      const rejected = result.status >= 400 && result.status < 500 && result.status !== 408;
      // Checkout validation runs after checking for an invoice with this request ID.
      if (result.error.code === "22023" || (rejected && !request.uncertain)) {
        setPendingPosCheckout(cashierId, null);
      }
      throw new Error(result.error.message);
    }
    const sale = Array.isArray(result.data) ? result.data[0] : result.data;
    if (!sale?.invoice_number) throw new Error("تعذّر قراءة نتيجة الحفظ.");

    savedSale = sale;
    setPendingPosCheckout(cashierId, null);
    if (currentUser?.id !== cashierId) return;
    cartItems = [];
    status.textContent = `تم تسجيل الفاتورة ${sale.invoice_number}.`;
    renderPosReceipt();
    await Promise.all([loadInventory(), loadPosHistory()]);
  } catch (error) {
    if (currentUser?.id !== cashierId) return;
    if (savedSale) {
      status.textContent = `تم تسجيل الفاتورة ${savedSale.invoice_number}. تعذّر تحديث العرض.`;
    } else if (readPendingPosCheckout()?.id === request.id) {
      status.textContent = "تعذّر تأكيد الحفظ. اضغط زر التحقق لاسترجاع الفاتورة أو إكمال تسجيلها.";
    } else {
      status.textContent = `تعذّر إتمام البيع. ${error.message}`;
      await loadInventory();
      for (const item of cartItems) {
        const product = productsList.find(product => product.id === item.product.id);
        if (product) item.product = product;
      }
    }
  } finally {
    posCheckoutBusy = false;
    renderPosReceipt();
  }
  if (savedSale && currentUser?.id === cashierId) printPosInvoice(savedSale);
}

function summarizePosShift(rows, day) {
  let salesCents = 0;
  let returnCents = 0;
  let count = 0;
  for (const sale of rows) {
    if (sale.sale_date === day) {
      salesCents += Math.round(Number(sale.total_amount) * 100);
      count += 1;
    }
    if (sale.return_date === day && sale.status === "returned") {
      returnCents += Math.round(Number(sale.returned_amount ?? sale.total_amount) * 100);
    }
  }
  return { sales: salesCents / 100, returns: returnCents / 100, net: (salesCents - returnCents) / 100, count };
}

function renderPosHistory(message = "") {
  const rows = document.getElementById("posHistoryRows");
  if (!rows) return;
  const totals = posHistoryDay ? summarizePosShift(posHistoryRows, posHistoryDay) : null;
  document.getElementById("posHistoryDate").textContent = posHistoryDay || cairoDateKey();
  document.getElementById("posHistoryStatus").textContent = message;
  document.getElementById("btnPrintPosShift").disabled = !totals;
  document.getElementById("posSalesAmount").textContent = totals ? formatPosMoney(totals.sales) : "—";
  document.getElementById("posReturnsAmount").textContent = totals ? formatPosMoney(totals.returns) : "—";
  document.getElementById("posShiftNet").textContent = totals ? formatPosMoney(totals.net) : "—";
  document.getElementById("posInvoiceCount").textContent = totals ? totals.count : "—";

  rows.innerHTML = posHistoryRows.map(sale => {
    const returned = sale.status === "returned";
    return `
      <tr>
        <td><bdi>${escapeHtml(sale.invoice_number)}</bdi></td>
        <td>${posTimeFormatter.format(new Date(sale.created_at))}</td>
        <td><bdi>${escapeHtml(sale.cashier_email || "—")}</bdi></td>
        <td>${formatPosMoney(sale.total_amount)}</td>
        <td><span class="badge ${returned ? "badge-warning" : "badge-success"}">${returned ? "مرتجع" : "مكتملة"}</span></td>
        <td>
          <div class="table-actions">
            <button type="button" class="btn btn-secondary btn-sm" data-print-sale="${escapeHtml(sale.id)}">
              <i class="fa-solid fa-print" aria-hidden="true"></i> إعادة طباعة الفاتورة
            </button>
            ${returned ? "" : `<button type="button" class="btn btn-danger btn-sm" data-return-sale="${escapeHtml(sale.id)}"
              ${posReturnsInProgress.has(sale.id) ? "disabled" : ""}>عمل مرتجع</button>`}
          </div>
        </td>
      </tr>
    `;
  }).join("");
  if (totals && !posHistoryRows.length) {
    rows.innerHTML = '<tr><td colspan="6" class="empty-table-cell">لا توجد فواتير أو مرتجعات لهذا اليوم.</td></tr>';
  }
}

async function loadPosHistory() {
  if (!currentUser) return false;
  const request = Symbol();
  const day = cairoDateKey();
  posHistoryRequest = request;
  posHistoryRows = [];
  posHistoryDay = "";
  renderPosHistory("جارٍ تحميل فواتير اليوم والمرتجعات…");

  try {
    const pageSize = 200;
    const sales = [];
    for (let offset = 0; ; offset += pageSize) {
      const { data, error } = await supabaseClient.from("pos_sales")
        .select("id, invoice_number, items, total_amount, cashier_email, status, created_at, sale_date, return_date, returned_amount")
        .or(`sale_date.eq.${day},return_date.eq.${day}`)
        .order("created_at", { ascending: false })
        .order("id", { ascending: false })
        .range(offset, offset + pageSize - 1);
      if (posHistoryRequest !== request) return false;
      if (error) throw error;
      sales.push(...data);
      if (data.length < pageSize) break;
    }
    posHistoryRows = sales;
    posHistoryDay = day;
    renderPosHistory();
    return true;
  } catch (error) {
    if (posHistoryRequest === request) renderPosHistory(`تعذّر تحميل سجل الفواتير. ${error.message}`);
    return false;
  }
}

function handlePosHistoryAction(event) {
  const button = event.target.closest("button[data-print-sale], button[data-return-sale]");
  if (!button) return;
  const sale = posHistoryRows.find(sale => sale.id === (button.dataset.printSale || button.dataset.returnSale));
  if (!sale) return;
  if (button.dataset.printSale) printPosInvoice(sale);
  else refundPosSale(sale);
}

async function refundPosSale(sale) {
  const cashierId = currentUser?.id;
  if (!cashierId || sale.status === "returned" || posReturnsInProgress.has(sale.id)) return;
  if (!confirm(`هل تريد إرجاع كامل الفاتورة ${sale.invoice_number} وإعادة كمياتها إلى المخزون؟`)) return;

  posReturnsInProgress.add(sale.id);
  renderPosHistory("جارٍ تسجيل المرتجع…");
  try {
    const { error } = await supabaseClient.rpc("return_pos_sale", { p_sale_id: sale.id });
    if (error) throw error;
    if (currentUser?.id === cashierId) await Promise.all([loadInventory(), loadPosHistory()]);
  } catch (error) {
    if (currentUser?.id === cashierId) alert(`تعذّر تأكيد المرتجع. ${error.message}`);
  } finally {
    posReturnsInProgress.delete(sale.id);
    if (currentUser?.id === cashierId) renderPosHistory(document.getElementById("posHistoryStatus").textContent);
  }
}

function printPosDocument(html) {
  const printArea = document.getElementById("posPrintArea");
  printArea.innerHTML = html;
  document.body.classList.add("pos-printing");
  try {
    window.print();
  } catch (error) {
    document.body.classList.remove("pos-printing");
    alert(`تعذّر فتح الطباعة. ${error.message}`);
  }
}

function printPosInvoice(sale) {
  const items = Array.isArray(sale.items) ? sale.items : [];
  printPosDocument(`
    <h2>سوق التل</h2>
    <p><strong>فاتورة <bdi>${escapeHtml(sale.invoice_number)}</bdi></strong></p>
    <p>${posTimeFormatter.format(new Date(sale.created_at))}</p>
    <p>الكاشير <bdi>${escapeHtml(sale.cashier_email || "—")}</bdi></p>
    ${sale.status === "returned" ? `<p><strong>مرتجع</strong> ${formatPosMoney(sale.returned_amount ?? sale.total_amount)}</p>` : ""}
    <table>
      <thead><tr><th scope="col">الصنف</th><th scope="col">الكمية</th><th scope="col">سعر الوحدة</th><th scope="col">الإجمالي</th></tr></thead>
      <tbody>${items.map(item => `
        <tr>
          <td>${escapeHtml(item.name)}</td>
          <td>${escapeHtml(item.quantity)} ${escapeHtml(item.unit || "قطعة")}</td>
          <td>${formatPosMoney(item.price)}</td>
          <td>${formatPosMoney(item.line_total)}</td>
        </tr>`
      ).join("")}</tbody>
    </table>
    <p><strong>إجمالي الفاتورة ${formatPosMoney(sale.total_amount)}</strong></p>
  `);
}

async function printPosShift() {
  if (!await loadPosHistory()) return;
  const totals = summarizePosShift(posHistoryRows, posHistoryDay);
  printPosDocument(`
    <h2>سوق التل</h2>
    <p><strong>تقرير تقفيل الوردية</strong></p>
    <p>تاريخ الوردية <bdi>${posHistoryDay}</bdi></p>
    <p>إجمالي المبيعات ${formatPosMoney(totals.sales)}</p>
    <p>إجمالي المرتجعات ${formatPosMoney(totals.returns)}</p>
    <p><strong>صافي الوردية ${formatPosMoney(totals.net)}</strong></p>
    <p>عدد الفواتير ${totals.count}</p>
  `);
}

// Camera Scanner Modal Controls
let activeScanTarget = "productBarcode";

async function openCameraModal(target = "productBarcode") {
  activeScanTarget = target;
  document.getElementById("cameraModal").classList.add("active");

  try {
    if (html5QrCode) {
      try { await html5QrCode.stop(); } catch (_) {}
      try { html5QrCode.clear(); } catch (_) {}
    }

    const formatsSupported = [
      Html5QrcodeSupportedFormats.EAN_13,
      Html5QrcodeSupportedFormats.EAN_8,
      Html5QrcodeSupportedFormats.CODE_128,
      Html5QrcodeSupportedFormats.CODE_39,
      Html5QrcodeSupportedFormats.UPC_A,
      Html5QrcodeSupportedFormats.UPC_E,
      Html5QrcodeSupportedFormats.QR_CODE
    ];

    html5QrCode = new Html5Qrcode("reader", {
      formatsToSupport: formatsSupported,
      experimentalFeatures: {
        useBarCodeDetectorIfSupported: true
      }
    });

    const config = {
      fps: 15,
      qrbox: { width: 300, height: 140 },
      aspectRatio: 1.0,
      videoConstraints: {
        width: { min: 640, ideal: 1280 },
        height: { min: 480, ideal: 720 }
      }
    };

    const onScanSuccess = (decodedText) => {
      closeCameraModal();
      const cleaned = cleanBarcode(decodedText);
      if (activeScanTarget === "pos") {
        scanAndAddToCart(cleaned);
      } else {
        const input = document.getElementById(activeScanTarget);
        if (input) {
          input.value = cleaned;
          const isModal = activeScanTarget.startsWith("modalEdit");
          lookupBarcodeOnline(activeScanTarget, isModal);
        }
      }
    };

    try {
      const devices = await Html5Qrcode.getCameras();
      if (devices && devices.length > 0 && devices[0].id) {
        await html5QrCode.start(devices[0].id, config, onScanSuccess, () => {});
        return;
      }
    } catch (e) {
      console.warn("getCameras fallback:", e);
    }

    try {
      await html5QrCode.start({ facingMode: "user" }, config, onScanSuccess, () => {});
      return;
    } catch (e) {
      console.warn("user camera fallback:", e);
    }

    await html5QrCode.start({ facingMode: "environment" }, config, onScanSuccess, () => {});

  } catch (err) {
    console.error("Camera scanner error:", err);
    alert("⚠️ تعذر تشغيل الكاميرا. يمكنك إدخال الباركود يدوياً أو بمسدس السكانر الـ USB.");
    closeCameraModal();
  }
}

function openCameraModalForPos() {
  openCameraModal("pos");
}

function closeCameraModal() {
  const modal = document.getElementById("cameraModal");
  if (modal) modal.classList.remove("active");

  if (html5QrCode) {
    try {
      html5QrCode.stop().then(() => {
        try { html5QrCode.clear(); } catch (_) {}
      }).catch(() => {
        try { html5QrCode.clear(); } catch (_) {}
      });
    } catch (_) {}
  }
}

// ==========================================
// Unified Barcode Lookup (Warehouse DB & Global APIs)
// ==========================================
function parseGlobalProductData(p) {
  if (!p) return null;

  // Name
  const name = p.product_name_ar || p.product_name || p.product_name_en || p.generic_name_ar || p.generic_name || p.product_name_fr || p.title || '';
  if (!name) return null;

  // Brand
  let brand = p.brands || p.brand_owner || p.brands_imported || '';
  if (!brand && Array.isArray(p.brands_tags) && p.brands_tags.length > 0) {
    brand = p.brands_tags.map(b => b.replace(/^en:|^ar:|^fr:/, '')).filter(Boolean).join(', ');
  }

  // Size / Volume / Quantity
  let size = p.quantity || p.serving_size || '';
  if (!size && p.product_quantity) {
    size = `${p.product_quantity} ${p.product_quantity_unit || ''}`.trim();
  }
  if (!size && p.net_weight_value) {
    size = `${p.net_weight_value} ${p.net_weight_unit || 'g'}`.trim();
  }

  // Image URL
  let imageUrl = p.image_front_url || p.image_url || p.image_front_small_url || p.image_small_url || '';
  if (!imageUrl && p.selected_images && p.selected_images.front && p.selected_images.front.display) {
    const display = p.selected_images.front.display;
    imageUrl = display.ar || display.en || display.fr || Object.values(display)[0] || '';
  }

  // Category Hint
  let categoryHint = p.categories || p.categories_old || '';
  if (!categoryHint && Array.isArray(p.categories_tags) && p.categories_tags.length > 0) {
    categoryHint = p.categories_tags.map(c => c.replace(/^en:|^ar:|^fr:/, '')).filter(Boolean).join(' ');
  }

  // Country
  let country = p.countries || p.countries_imported || p.origin || p.origins || '';
  if (!country && Array.isArray(p.countries_tags) && p.countries_tags.length > 0) {
    country = p.countries_tags.map(c => c.replace(/^en:|^ar:|^fr:/, '')).filter(Boolean).join(', ');
  }

  // Description / Ingredients
  const description = p.generic_name_ar || p.generic_name || p.ingredients_text_ar || p.ingredients_text || p.categories || '';

  return {
    name: name.trim(),
    brand: brand.trim(),
    size: size.trim(),
    imageUrl: imageUrl.trim(),
    categoryHint: categoryHint.trim(),
    country: country.trim(),
    description: description.trim()
  };
}

// Parse data from UPCitemdb API response (احتياطي للإلكترونيات والمنتجات العامة)
function parseUpcItemDbData(item) {
  if (!item || !item.title) return null;
  const name = item.title || '';
  const brand = item.brand || '';
  const size  = item.size || item.dimension || item.weight || '';
  const imageUrl = (Array.isArray(item.images) && item.images.length > 0) ? item.images[0] : '';
  const description = item.description || item.category || '';
  const country = item.origin || '';
  const categoryHint = item.category || '';
  return { name: name.trim(), brand: brand.trim(), size: size.trim(), imageUrl: imageUrl.trim(), categoryHint: categoryHint.trim(), country: country.trim(), description: description.trim() };
}

// Lookup barcode via Supabase Edge Function (Google Shopping / Google Egypt)
async function lookupBarcodeFromGoogleEdge(barcode) {
  try {
    return await requestGoogleProductLookup({ barcode });
  } catch (err) {
    console.warn("Google Edge lookup error:", err);
    return null;
  }
}

async function requestGoogleProductLookup(payload, signal) {
  const headers = { "Content-Type": "application/json" };
  if (payload.query) {
    const { data, error } = await supabaseClient.auth.getSession();
    if (error) throw error;
    if (data?.session?.access_token) headers.Authorization = `Bearer ${data.session.access_token}`;
  }
  const response = await fetch(`${SUPABASE_URL}/functions/v1/barcode-google-lookup`, {
    method: "POST",
    headers,
    body: JSON.stringify(payload),
    signal
  });
  if (!response.ok) throw new Error(`Google product lookup failed (HTTP ${response.status})`);
  const data = await response.json();
  return data?.found === true ? data.product || null : null;
}
function autoSelectProductCategory(categorySelect, { categoryHint, name, description }) {
  if (!categorySelect) return;

  const normalize = (text) => String(text ?? "")
    .normalize("NFKD")
    .toLowerCase()
    .replace(/[\p{M}ـ]/gu, "")
    .replace(/ى/g, "ي")
    .replace(/ة/g, "ه")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim();
  const containsPhrase = (text, phrase) => phrase &&
    (text.includes(" " + phrase + " ") || text.includes(" ال" + phrase + " "));
  const withoutFlavor = (text) => normalize(text).split(/(?:^| )(?:بطعم|بنكهه|flavored|flavoured)(?: |$)/)[0].trim();

  const keywords = [
    [["سناكس", "تسالي", "مقرمشات", "مكسرات", "وجبات خفيفة", "snacks"],
     ["سناكس", "تسالي", "مقرمشات", "مكسرات", "شيبسي", "شيبس", "سوداني", "كري كري", "فشار", "chips", "peanuts", "popcorn"]],
    [["مشروبات", "عصائر", "beverages", "drinks"],
     ["عصير", "مشروب", "مياه معدنية", "مياه غازية", "juice", "soda", "sparkling water"]],
    [["ألبان", "أجبان", "dairy"],
     ["حليب", "لبن", "زبادي", "جبنة", "جبن", "milk", "yogurt", "cheese"]],
    [["حلويات", "حلوى", "sweets", "confectionery"],
     ["شوكولاتة", "شيكولاتة", "بسكويت", "حلوى", "chocolate", "biscuits", "cookies", "candy"]],
    [["مخبوزات", "bakery"],
     ["خبز", "توست", "كرواسون", "كيك", "bread", "croissant", "cake"]],
    [["منظفات", "مواد تنظيف", "cleaning supplies"],
     ["مسحوق غسيل", "سائل غسيل", "منظف", "مطهر", "detergent", "disinfectant"]],
    [["عناية شخصية", "personal care"],
     ["شامبو", "معجون أسنان", "مزيل عرق", "shampoo", "toothpaste", "deodorant"]],
  ];
  const options = Array.from(categorySelect.options)
    .filter((option) => option.value && !option.disabled)
    .map((option) => ({ option, label: normalize(option.textContent) }));

  for (const source of [normalize(categoryHint), withoutFlavor(name), withoutFlavor(description)]) {
    if (!source) continue;
    const text = " " + source + " ";
    let matches = options.filter(({ label }) => containsPhrase(text, label));
    if (matches.length === 0) {
      const rules = keywords.filter(([, terms]) =>
        terms.some((term) => containsPhrase(text, normalize(term))));
      matches = options.filter(({ label }) => rules.some(([labels]) =>
        labels.some((alias) => containsPhrase(" " + label + " ", normalize(alias)))));
    }
    if (matches.length === 0) continue;
    if (matches.length === 1 && categorySelect.value !== matches[0].option.value) {
      categorySelect.value = matches[0].option.value;
      categorySelect.dispatchEvent(new Event("change", { bubbles: true }));
    }
    return;
  }
}

const barcodeLookupRequests = new WeakMap();

async function lookupBarcodeOnline(inputElementId = "productBarcode", isModal = false) {
  const prefix = isModal ? "modalEdit" : "product";
  const targetId = inputElementId || `${prefix}Barcode`;
  const inputEl = document.getElementById(targetId);
  if (!inputEl) return;
  const barcode = cleanBarcode(inputEl.value);

  if (!barcode) {
    alert("⚠️ الرجاء كتابة أو مسح رقم الباركود أولاً للبحث عنه.");
    inputEl.focus();
    return;
  }

  inputEl.value = barcode;
  refreshVariantSkus(prefix);
  const request = Symbol();
  barcodeLookupRequests.set(inputEl, request);
  const isLatestLookup = () => barcodeLookupRequests.get(inputEl) === request;
  const isCurrentLookup = () => isLatestLookup() && cleanBarcode(inputEl.value) === barcode;
  const categorySelect = document.getElementById(`${prefix}Category`);
  const initialCategory = categorySelect?.value;

  const statusEl = document.getElementById(isModal ? "lookupStatusModal" : "lookupStatusMain");
  const showStatus = (contentHtml, type = "loading") => {
    if (!statusEl) return;
    statusEl.className = `lookup-status-banner ${type}`;
    let icon = '<i class="fa-solid fa-spinner fa-spin"></i>';
    if (type === "success") icon = '<i class="fa-solid fa-circle-check"></i>';
    else if (type === "info") icon = '<i class="fa-solid fa-circle-info"></i>';
    else if (type === "error") icon = '<i class="fa-solid fa-triangle-exclamation"></i>';

    statusEl.innerHTML = `
      <div class="lookup-status-content">
        ${icon}
        <div style="flex:1;">${contentHtml}</div>
      </div>
    `;
    statusEl.classList.remove("hidden");
  };

  const hideStatus = () => {
    if (statusEl && isLatestLookup()) statusEl.classList.add("hidden");
  };

  showStatus(`جاري فحص الباركود (${barcode})...`, "loading");

  try {
    // 1. أولاً: فحص قاعدة بيانات المستودع (الكاش المحلي + Supabase)
    const localProd = await findProductByBarcode(barcode);
    if (!isCurrentLookup()) {
      hideStatus();
      return;
    }

    if (localProd) {
      populateProductForm(localProd, prefix, barcode);
      showStatus(`✅ تم العثور على السلعة المسجلة بالمستودع: "<strong>${localProd.name}</strong>" بنجاح وتم تعبئة بياناتها!`, "success");
      setTimeout(hideStatus, 6000);
      return;
    }

    // 2. ثانياً: إذا لم تكن مسجلة في المستودع
    const isLocal = isLocalBarcode(barcode);
    const unlinkedOptionsHtml = getUnlinkedProductsOptions();

    // الحالة أ: باركود محلي داخلي (200... أو ST-...)
    // لا يتم البحث في المواقع العالمية أبداً للباركود المحلي!
    if (isLocal) {
      showStatus(`
        <div class="lookup-status-banner-card local-barcode">
          <div class="banner-top">
            <i class="fa-solid fa-circle-check text-success"></i>
            <span><strong>تم استقبال الباركود المحلي بنجاح (<code>${barcode}</code>):</strong> كود محلي داخلي جاهز للتسجيل.</span>
          </div>
          <div class="banner-hint">اكتب اسم السلعة وسعرها أدناه وحفظها، أو اربط هذا الباركود بسلعة مسجلة مسبقاً بالمستودع:</div>
          ${unlinkedOptionsHtml ? `
            <div class="quick-link-select-row">
              <label for="linkSelect_${prefix}"><i class="fa-solid fa-link"></i> ربط هذا الباركود بسلعة مسجلة:</label>
              <select id="linkSelect_${prefix}" onchange="linkBarcodeToExistingProduct(this.value, '${barcode}', '${prefix}')">
                <option value="">-- اضغط هنا لاختيار سلعة من المستودع لربطها بالباركود --</option>
                ${unlinkedOptionsHtml}
              </select>
            </div>
          ` : ''}
        </div>
      `, "info");

      const nameInput = document.getElementById(`${prefix}Name`);
      if (nameInput && !nameInput.value) {
        setTimeout(() => nameInput.focus(), 150);
      }
      return;
    }

    // الحالة ب: باركود دولي مصنعي (مثل EAN-13 أو UPC)
    showStatus(`جاري فحص السجل التجاري الدولي للباركود (${barcode})...`, "loading");

    let result = null;
    try {
      const fetchWithTimeout = (url, ms = 2500) => {
        const controller = new AbortController();
        const t = setTimeout(() => controller.abort(), ms);
        return fetch(url, { signal: controller.signal }).finally(() => clearTimeout(t));
      };

      // محاولة 1: Open Food Facts (العالمي + مصر)
      const offResults = await Promise.allSettled([
        fetchWithTimeout(`https://world.openfoodfacts.org/api/v0/product/${encodeURIComponent(barcode)}.json`),
        fetchWithTimeout(`https://eg.openfoodfacts.org/api/v0/product/${encodeURIComponent(barcode)}.json`)
      ]);
      for (const response of offResults) {
        if (response.status !== "fulfilled" || !response.value.ok) continue;
        try {
          const data = await response.value.json();
          if ((data?.status === 1 || data?.status_verbose === "product found") && data.product) {
            result = parseGlobalProductData(data.product);
            if (result) break;
          }
        } catch (error) {
          console.warn("Open Food Facts lookup error:", error);
        }
      }
      if (!isCurrentLookup()) {
        hideStatus();
        return;
      }

      // محاولة 2: Google Edge Function (احتياطي للمنتجات المصرية والدولية عبر Supabase)
      // يُستدعى إذا لم يُعثر على اسم المنتج أو كانت صورته فارغة
      if (!result || !result.name || !result.imageUrl) {
        showStatus(`جاري البحث في قاعدة البيانات الدولية (${barcode})...`, "loading");
        const googleProduct = await lookupBarcodeFromGoogleEdge(barcode);
        if (googleProduct) {
          result = {
            name:        result?.name        || googleProduct.name        || "",
            brand:       result?.brand       || googleProduct.brand       || "",
            size:        result?.size        || googleProduct.size        || "",
            country:     result?.country     || googleProduct.country     || "",
            imageUrl:    result?.imageUrl    || googleProduct.image_url   || "",
            description: result?.description || googleProduct.description || "",
            categoryHint: result?.categoryHint || "",
          };
        }
      }
    } catch (e) {
      console.warn("Online barcode lookup error:", e);
    }
    if (!isCurrentLookup()) {
      hideStatus();
      return;
    }

    if (result && result.name) {
      const nameInput = document.getElementById(`${prefix}Name`);
      const brandInput = document.getElementById(`${prefix}Brand`);
      const sizeInput = document.getElementById(`${prefix}Size`);
      const imageInput = document.getElementById(`${prefix}ImageUrl`);
      const descInput = document.getElementById(`${prefix}Description`);
      const originInput = document.getElementById(`${prefix}Origin`);

      if (nameInput) nameInput.value = result.name;
      if (brandInput && result.brand) brandInput.value = result.brand;
      if (sizeInput && result.size) sizeInput.value = result.size;
      if (imageInput && result.imageUrl) {
        imageInput.value = result.imageUrl;
        updateImagePreview(`${prefix}ImageUrl`, `${prefix}ImagePreview`, `${prefix}ImagePlaceholder`);
      }
      if (originInput && result.country) originInput.value = result.country;
      if (descInput && result.description) descInput.value = result.description;
      autoSelectProductSubCategory(result.name, result.description, result.brand, prefix);
      if (categorySelect && categorySelect.value === initialCategory) {
        autoSelectProductCategory(categorySelect, result);
      }
      showStatus(`✅ تم جلب بيانات السلعة من السجل الدولي: "<strong>${escapeHtml(result.name)}</strong>" بنجاح وتعبئة الحقول المتاحة!`, "success");
      setTimeout(hideStatus, 8000);
    } else {
      const googleSearchUrl = `https://www.google.com/search?q=${encodeURIComponent(barcode)}`;
      showStatus(`
        <div class="lookup-status-banner-card intl-barcode">
          <div class="banner-top">
            <i class="fa-solid fa-barcode text-primary"></i>
            <span><strong>تم استقبال الباركود الدولي بنجاح (<code>${barcode}</code>):</strong> السلعة جديدة وغير مسجلة بعد.</span>
          </div>
          <div class="banner-hint">اكتب اسم السلعة وسعرها أدناه وحفظها، أو اختر سلعة مسجلة لربط هذا الباركود بها:</div>
          ${unlinkedOptionsHtml ? `
            <div class="quick-link-select-row">
              <label for="linkSelect_${prefix}"><i class="fa-solid fa-link"></i> ربط هذا الباركود بسلعة مسجلة:</label>
              <select id="linkSelect_${prefix}" onchange="linkBarcodeToExistingProduct(this.value, '${barcode}', '${prefix}')">
                <option value="">-- اضغط هنا لاختيار سلعة من المستودع لربطها بالباركود --</option>
                ${unlinkedOptionsHtml}
              </select>
            </div>
          ` : ''}
          <div style="margin-top: 6px;">
            <a href="${googleSearchUrl}" target="_blank" rel="noopener noreferrer" class="lookup-google-link">
              <i class="fa-brands fa-google"></i> البحث عن تفاصيل الباركود في Google
            </a>
          </div>
        </div>
      `, "info");

      const nameInput = document.getElementById(`${prefix}Name`);
      if (nameInput && !nameInput.value) {
        setTimeout(() => nameInput.focus(), 150);
      }
      setTimeout(hideStatus, 25000);
    }
  } catch (err) {
    if (!isCurrentLookup()) {
      hideStatus();
      return;
    }
    console.error("Barcode lookup error:", err);
    showStatus(`❌ تعذر جلب البيانات: ${err.message}`, "error");
    setTimeout(hideStatus, 6000);
  }
}

/* ============================================================
   FBN (Fulfilled By Noon style) Item Tracking Label System
   ============================================================ */

let fbnItemsList = [];
let currentFbnLabelSize = "50x25";
let activePreviewProductId = null;

/**
 * Generate Internal Barcode in Noon FBN format:
 * Format: ST-MERCHANTID-PRODUCTSKU-UNIQUEHASH
 * Example: ST-M041-P309-8F2D
 */
function generateFbnBarcode(product, store) {
  const cf = product.custom_fields || {};
  if (cf.fbn_barcode && cf.fbn_barcode.startsWith("ST-")) {
    return cf.fbn_barcode;
  }

  // 1. Merchant / Store Component
  let storeCode = "M001";
  const storeObj = store || product.stores || storesList.find(s => s.id === product.store_id);
  if (storeObj && storeObj.name) {
    const cleanStore = storeObj.name.replace(/[^a-zA-Z0-9]/g, "").toUpperCase();
    storeCode = "M" + (cleanStore.substring(0, 4) || (storeObj.id ? storeObj.id.replace(/-/g, "").substring(0, 3).toUpperCase() : "001"));
  } else if (product.store_id) {
    storeCode = "M" + product.store_id.replace(/-/g, "").substring(0, 3).toUpperCase();
  }

  // 2. Product SKU / Code Component
  const sanitizedSku = (product.sku || "").replace(/[^a-zA-Z0-9]/g, "").toUpperCase().substring(0, 6);
  const skuCode = sanitizedSku || ("P" + (product.id ? product.id.replace(/-/g, "").substring(0, 4).toUpperCase() : "001"));

  // 3. Unique Hash Component (4 hex characters)
  let hash = "A001";
  if (product.id) {
    const raw = product.id.replace(/-/g, "");
    hash = raw.length >= 8 ? raw.substring(raw.length - 4).toUpperCase() : "8F2D";
  } else {
    hash = Math.floor(Math.random() * 0xFFFF).toString(16).toUpperCase().padStart(4, "0");
  }

  const generatedBarcode = `ST-${storeCode}-${skuCode}-${hash}`;
  
  if (!product.custom_fields) product.custom_fields = {};
  product.custom_fields.fbn_barcode = generatedBarcode;

  return generatedBarcode;
}

/**
 * Load items for FBN Labels Tab
 */
async function loadFbnItems() {
  const tbody = document.getElementById("fbnTableBody");
  if (tbody) {
    tbody.innerHTML = '<tr><td colspan="9" class="empty-table-cell"><i class="fa-solid fa-spinner fa-spin"></i> جاري تحميل السلع وتوليد ملصقات التتبع...</td></tr>';
  }

  // Ensure inventory is loaded
  if (!productsList || productsList.length === 0) {
    await loadInventory();
  }

  // Populate FBN Supplier filter dropdown
  const supFilter = document.getElementById("filterFbnSupplier");
  if (supFilter && supFilter.options.length <= 1) {
    supFilter.innerHTML = '<option value="">جميع الموردين والتجار</option>' +
      storesList.map(s => `<option value="${s.id}">${s.name}</option>`).join("");
  }

  // Populate FBN Category filter dropdown
  const catFilter = document.getElementById("filterFbnCategory");
  if (catFilter && catFilter.options.length <= 1) {
    catFilter.innerHTML = '<option value="">جميع الأقسام</option>' +
      categories.map(c => `<option value="${c.id}">${c.name}</option>`).join("");
  }

  // Clone items and attach FBN state
  fbnItemsList = productsList.map(p => {
    const existing = fbnItemsList.find(item => item.id === p.id);
    const storeObj = p.stores || storesList.find(s => s.id === p.store_id);
    const fbnCode = generateFbnBarcode(p, storeObj);

    return {
      ...p,
      fbn_barcode: fbnCode,
      fbn_selected: existing ? existing.fbn_selected : false,
      fbn_copies: existing ? existing.fbn_copies : 1
    };
  });

  applyFbnFilter();
}

/**
 * Filter items in FBN Table
 */
function applyFbnFilter() {
  const query = (document.getElementById("searchFbnItems")?.value || "").trim().toLowerCase();
  const supId = document.getElementById("filterFbnSupplier")?.value || "";
  const catId = document.getElementById("filterFbnCategory")?.value || "";

  const filtered = fbnItemsList.filter(p => {
    const cf = p.custom_fields || {};
    const name = (p.name || "").toLowerCase();
    const barcode = (p.barcode || cf.local_barcode || cf.international_barcode || "").toLowerCase();
    const fbnCode = (p.fbn_barcode || "").toLowerCase();
    const brand = (cf.brand || p.brand || "").toLowerCase();

    const matchesQuery = !query || name.includes(query) || barcode.includes(query) || fbnCode.includes(query) || brand.includes(query);
    const matchesSup = !supId || p.store_id === supId;
    const matchesCat = !catId || p.category_id === catId;

    return matchesQuery && matchesSup && matchesCat;
  });

  renderFbnTable(filtered);
  updateFbnSummary();
}

/**
 * Render FBN Items Table
 */
function renderFbnTable(items) {
  const tbody = document.getElementById("fbnTableBody");
  if (!tbody) return;

  if (!items || items.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" class="empty-table-cell">لا توجد سلع مطابقة لخيارات الفلترة الحالية</td></tr>';
    return;
  }

  tbody.innerHTML = items.map(p => {
    const cf = p.custom_fields || {};
    const storeName = p.stores?.name || (storesList.find(s => s.id === p.store_id)?.name) || 'مستودع سوق التل';
    const variations = [];
    if (cf.color) variations.push(`اللون: ${cf.color}`);
    if (cf.size || cf.volume || cf.weight || p.size) variations.push(`المقاس/الحجم: ${cf.size || cf.volume || cf.weight || p.size}`);
    const varText = variations.length > 0 ? variations.join(' | ') : '<span class="text-muted">قياسي</span>';

    const origBarcode = p.barcode || cf.local_barcode || cf.international_barcode || '-';
    const stockQty = p.stock_quantity ?? 0;
    const badgeClass = stockQty > 10 ? "badge-success" : stockQty > 0 ? "badge-warning" : "badge-danger";

    return `
      <tr class="${p.fbn_selected ? 'selected-row' : ''}">
        <td style="text-align: center;">
          <input type="checkbox" class="fbn-item-check" data-id="${p.id}" ${p.fbn_selected ? 'checked' : ''} onchange="toggleFbnItem('${p.id}', this.checked)">
        </td>
        <td>
          <div class="product-item-cell">
            ${p.image_url ? `<img src="${p.image_url}" class="product-thumb" alt="${p.name || ''}" onclick="openFullImage('${p.image_url}')">` : ''}
            <div>
              <strong>${p.name || 'بدون اسم'}</strong>
              <div class="product-desc-text">${p.description ? p.description.substring(0, 45) + '...' : ''}</div>
            </div>
          </div>
        </td>
        <td><strong>${storeName}</strong></td>
        <td>${varText}</td>
        <td>
          <span class="fbn-barcode-tag" title="باركود التتبع بنظام Code 128 (FBN)">
            <i class="fa-solid fa-barcode"></i>
            <code>${p.fbn_barcode}</code>
          </span>
        </td>
        <td><small class="text-muted">${origBarcode}</small></td>
        <td><span class="badge ${badgeClass}">${stockQty} قطعة</span></td>
        <td style="text-align: center;">
          <div class="qty-spinner-control">
            <button type="button" class="qty-spinner-btn" onclick="stepFbnQty('${p.id}', -1)" title="تقليل عدد النسخ">-</button>
            <input type="number" class="qty-spinner-input" id="fbnQty_${p.id}" value="${p.fbn_copies || 1}" min="1" max="999" onchange="updateFbnItemQty('${p.id}', this.value)">
            <button type="button" class="qty-spinner-btn" onclick="stepFbnQty('${p.id}', 1)" title="زيادة عدد النسخ">+</button>
          </div>
        </td>
        <td style="text-align: center;">
          <div class="table-actions" style="justify-content: center;">
            <button type="button" class="btn btn-primary btn-sm" onclick="printSingleFbn('${p.id}')" title="طباعة فورية لطابعة الملصقات">
              <i class="fa-solid fa-print"></i> طباعة
            </button>
            <button type="button" class="btn btn-secondary btn-sm" onclick="previewFbnLabel('${p.id}')" title="معاينة شكل الملصق">
              <i class="fa-solid fa-eye"></i>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join("");
}

/**
 * Toggle Item Selection
 */
function toggleFbnItem(productId, isChecked) {
  const item = fbnItemsList.find(p => p.id === productId);
  if (item) {
    item.fbn_selected = isChecked;
  }
  updateFbnSummary();
}

/**
 * Toggle Select All
 */
function toggleSelectAllFbn(isChecked) {
  const checkboxes = document.querySelectorAll(".fbn-item-check");
  checkboxes.forEach(cb => {
    cb.checked = isChecked;
    const id = cb.getAttribute("data-id");
    const item = fbnItemsList.find(p => p.id === id);
    if (item) item.fbn_selected = isChecked;
  });

  const headerCheck = document.getElementById("fbnSelectAllCheckbox");
  if (headerCheck) headerCheck.checked = isChecked;

  updateFbnSummary();
}

/**
 * Step Quantity up/down
 */
function stepFbnQty(productId, delta) {
  const input = document.getElementById(`fbnQty_${productId}`);
  if (!input) return;
  let val = parseInt(input.value, 10) || 1;
  val = Math.max(1, Math.min(999, val + delta));
  input.value = val;
  updateFbnItemQty(productId, val);
}

/**
 * Update Item Quantity in Memory
 */
function updateFbnItemQty(productId, value) {
  const val = Math.max(1, parseInt(value, 10) || 1);
  const item = fbnItemsList.find(p => p.id === productId);
  if (item) {
    item.fbn_copies = val;
  }
  updateFbnSummary();
}

/**
 * Set all visible items to N copies
 */
function setAllFbnCopies(n) {
  const val = Math.max(1, parseInt(n, 10) || 1);
  fbnItemsList.forEach(p => {
    if (p.fbn_selected || document.querySelectorAll(".fbn-item-check:checked").length === 0) {
      p.fbn_copies = val;
      const input = document.getElementById(`fbnQty_${p.id}`);
      if (input) input.value = val;
    }
  });
  updateFbnSummary();
}

/**
 * Set all visible items copies equal to stock quantity
 */
function setFbnCopiesToStock() {
  fbnItemsList.forEach(p => {
    if (p.fbn_selected || document.querySelectorAll(".fbn-item-check:checked").length === 0) {
      const stock = Math.max(1, p.stock_quantity || 1);
      p.fbn_copies = stock;
      const input = document.getElementById(`fbnQty_${p.id}`);
      if (input) input.value = stock;
    }
  });
  updateFbnSummary();
}

/**
 * Update selection summary badge and print button text
 */
function updateFbnSummary() {
  const selectedItems = fbnItemsList.filter(p => p.fbn_selected);
  const totalStickers = selectedItems.reduce((sum, p) => sum + (p.fbn_copies || 1), 0);

  const summaryEl = document.getElementById("fbnSelectionSummary");
  if (summaryEl) {
    summaryEl.innerHTML = `تم تحديد: <strong>${selectedItems.length}</strong> صنف | إجمالي الملصقات: <strong>${totalStickers}</strong> ملصق حراري`;
  }

  const btnText = document.getElementById("btnBatchPrintText");
  if (btnText) {
    btnText.innerText = `طباعة الملصقات (${totalStickers})`;
  }

  const btnBatch = document.getElementById("btnBatchPrintLabels");
  if (btnBatch) {
    btnBatch.disabled = totalStickers === 0;
  }
}

/**
 * Change Label Sticker Size
 */
function changeFbnLabelSize(sizeValue) {
  currentFbnLabelSize = sizeValue || "50x25";
  
  // Set dimensions for @page rule dynamically
  let width = 50;
  let height = 25;
  if (currentFbnLabelSize === "50x30") { width = 50; height = 30; }
  else if (currentFbnLabelSize === "40x25") { width = 40; height = 25; }
  else if (currentFbnLabelSize === "60x40") { width = 60; height = 40; }

  let styleTag = document.getElementById("dynamicThermalPageStyle");
  if (!styleTag) {
    styleTag = document.createElement("style");
    styleTag.id = "dynamicThermalPageStyle";
    document.head.appendChild(styleTag);
  }
  styleTag.innerHTML = `@page { size: ${width}mm ${height}mm !important; margin: 0mm !important; }`;

  // If preview modal is open, re-render preview
  if (activePreviewProductId) {
    previewFbnLabel(activePreviewProductId);
  }
}

/**
 * Create Single Thermal Sticker DOM Element
 */
function createStickerElement(product, copyNum = 1, sizeClass = "size-50x25") {
  const cf = product.custom_fields || {};
  const storeName = product.stores?.name || (storesList.find(s => s.id === product.store_id)?.name) || 'مستودع سوق التل';
  const fbnCode = product.fbn_barcode || generateFbnBarcode(product);
  const todayStr = new Date().toISOString().split('T')[0];

  const variations = [];
  if (cf.color) variations.push(cf.color);
  if (cf.size || cf.volume || cf.weight || product.size) variations.push(cf.size || cf.volume || cf.weight || product.size);
  const varText = variations.length > 0 ? variations.join(' | ') : 'جديد (New)';

  const container = document.createElement("div");
  container.className = `thermal-label-sticker ${sizeClass}`;

  const uniqueSvgId = `fbn_svg_${product.id.replace(/-/g, '_')}_${copyNum}_${Math.random().toString(36).substr(2, 6)}`;

  container.innerHTML = `
    <div class="label-header">
      <span class="label-merchant" title="${storeName}">${storeName}</span>
      <span class="label-date">${todayStr}</span>
    </div>
    <div class="label-product-title" title="${product.name || ''}">${product.name || 'بدون اسم'}</div>
    <div class="label-barcode-box">
      <svg class="label-barcode-svg" id="${uniqueSvgId}"></svg>
    </div>
    <div class="label-footer">
      <span class="label-variation">${varText}</span>
      <span class="label-fbn-brand">SOUQ EL TAL FBN</span>
      ${product.price ? `<span class="label-price">${product.price} ج.م</span>` : ''}
    </div>
  `;

  return { container, svgId: uniqueSvgId, barcode: fbnCode };
}

/**
 * Render JsBarcode on SVG element
 */
function renderBarcodeSvg(svgId, barcodeValue, sizeClass) {
  const svgEl = document.getElementById(svgId);
  if (!svgEl) return;

  if (typeof JsBarcode === "undefined") {
    console.error("JsBarcode library not loaded!");
    return;
  }

  let barWidth = 1.25;
  let barHeight = 28;
  let fontSize = 9.5;

  if (sizeClass === "size-40x25") {
    barWidth = 1.0;
    barHeight = 22;
    fontSize = 8;
  } else if (sizeClass === "size-50x30") {
    barWidth = 1.3;
    barHeight = 36;
    fontSize = 10;
  } else if (sizeClass === "size-60x40") {
    barWidth = 1.6;
    barHeight = 48;
    fontSize = 11;
  }

  try {
    JsBarcode(svgEl, barcodeValue, {
      format: "CODE128",
      width: barWidth,
      height: barHeight,
      displayValue: true,
      font: "monospace",
      fontSize: fontSize,
      textMargin: 1,
      margin: 0,
      lineColor: "#000000"
    });
  } catch (e) {
    console.warn("JsBarcode render fallback for:", barcodeValue, e);
  }
}

/**
 * Open Live Preview Modal for a Product
 */
function previewFbnLabel(productId) {
  const product = fbnItemsList.find(p => p.id === productId) || productsList.find(p => p.id === productId);
  if (!product) {
    alert("السلعة غير موجودة!");
    return;
  }

  activePreviewProductId = productId;
  const modalContainer = document.getElementById("fbnModalPreviewContainer");
  const modalInfo = document.getElementById("fbnModalPreviewInfo");
  if (!modalContainer) return;

  modalContainer.innerHTML = "";

  const sizeClass = `size-${currentFbnLabelSize}`;
  const { container, svgId, barcode } = createStickerElement(product, 1, sizeClass);
  modalContainer.appendChild(container);

  renderBarcodeSvg(svgId, barcode, sizeClass);

  if (modalInfo) {
    modalInfo.innerHTML = `
      <div><strong>السلعة:</strong> ${product.name}</div>
      <div><strong>كود تتبع FBN:</strong> <code>${barcode}</code> | <strong>المقاس الحراري:</strong> ${currentFbnLabelSize} مم</div>
    `;
  }

  const modal = document.getElementById("fbnPreviewModal");
  if (modal) modal.classList.add("active");
}

function closeFbnPreviewModal() {
  const modal = document.getElementById("fbnPreviewModal");
  if (modal) modal.classList.remove("active");
  activePreviewProductId = null;
}

function printSingleFbnFromModal() {
  if (!activePreviewProductId) return;
  const pId = activePreviewProductId;
  closeFbnPreviewModal();
  printSingleFbn(pId);
}

/**
 * Print Single Item (N copies)
 */
function printSingleFbn(productId) {
  const product = fbnItemsList.find(p => p.id === productId) || productsList.find(p => p.id === productId);
  if (!product) return;

  const copiesInput = document.getElementById(`fbnQty_${productId}`);
  const copies = copiesInput ? parseInt(copiesInput.value, 10) || 1 : (product.fbn_copies || 1);

  executeThermalPrint([{ product, copies }]);
}

/**
 * Print Selected Items in Bulk
 */
function printSelectedFbnLabels() {
  const selected = fbnItemsList.filter(p => p.fbn_selected);
  if (selected.length === 0) {
    alert("⚠️ الرجاء تحديد سلعة واحدة على الأقل لطباعة ملصقاتها.");
    return;
  }

  const printQueue = selected.map(product => {
    const copiesInput = document.getElementById(`fbnQty_${product.id}`);
    const copies = copiesInput ? parseInt(copiesInput.value, 10) || 1 : (product.fbn_copies || 1);
    return { product, copies };
  });

  const totalCopies = printQueue.reduce((sum, item) => sum + item.copies, 0);
  if (confirm(`هل أنت مستعد لطباعة ${totalCopies} ملصق حراري لـ ${selected.length} صنف محدد؟`)) {
    executeThermalPrint(printQueue);
  }
}

/**
 * Execute Thermal Print: Builds DOM, Renders Barcodes, and Calls window.print()
 */
function executeThermalPrint(queue) {
  const printArea = document.getElementById("thermalPrintArea");
  if (!printArea) return;

  document.body.classList.remove("pos-printing");
  printArea.innerHTML = "";
  changeFbnLabelSize(currentFbnLabelSize);

  const pendingSvgRenders = [];
  const sizeClass = `size-${currentFbnLabelSize}`;

  queue.forEach(item => {
    const { product, copies } = item;
    for (let i = 1; i <= copies; i++) {
      const { container, svgId, barcode } = createStickerElement(product, i, sizeClass);
      printArea.appendChild(container);
      pendingSvgRenders.push({ svgId, barcode, sizeClass });
    }
  });

  // Render barcodes on each SVG
  pendingSvgRenders.forEach(({ svgId, barcode, sizeClass }) => {
    renderBarcodeSvg(svgId, barcode, sizeClass);
  });

  // Small delay to ensure browser layout & SVG painting is complete before print dialog
  setTimeout(() => {
    window.print();
  }, 250);
}


// ============================================================
// Image Upload & Processing Handlers
// ============================================================

function triggerImageUpload(fileInputId) {
  const fileInput = document.getElementById(fileInputId);
  if (fileInput) {
    fileInput.removeAttribute("capture");
    fileInput.click();
  }
}

// ============================================================
// 📸 Product Image Camera Capture Modal Controls
// ============================================================

let productPhotoStream = null;
let currentCameraFacingMode = "environment";
let activePhotoTarget = {
  urlInputId: "productImageUrl",
  previewImgId: "productImagePreview",
  placeholderId: "productImagePlaceholder"
};

function triggerCameraCapture(fileInputId) {
  const isModal = fileInputId && fileInputId.startsWith("modalEdit");
  const urlId = isModal ? "modalEditImageUrl" : "productImageUrl";
  const previewId = isModal ? "modalEditImagePreview" : "productImagePreview";
  const placeholderId = isModal ? "modalEditImagePlaceholder" : "productImagePlaceholder";
  const fallbackId = isModal ? "modalEditCameraFallbackInput" : "productCameraFallbackInput";

  if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
    openProductPhotoModal(urlId, previewId, placeholderId);
  } else {
    const fallbackInput = document.getElementById(fallbackId);
    if (fallbackInput) {
      fallbackInput.click();
    } else {
      const fileInput = document.getElementById(fileInputId);
      if (fileInput) {
        fileInput.setAttribute("capture", "environment");
        fileInput.click();
      }
    }
  }
}

async function openProductPhotoModal(urlInputId = "productImageUrl", previewImgId = "productImagePreview", placeholderId = "productImagePlaceholder") {
  activePhotoTarget = { urlInputId, previewImgId, placeholderId };

  const modal = document.getElementById("productPhotoModal");
  if (modal) modal.classList.add("active");

  const errorEl = document.getElementById("productPhotoCameraError");
  if (errorEl) errorEl.classList.add("hidden");

  await startProductCamera(currentCameraFacingMode);
}

async function startProductCamera(facingMode = "environment") {
  const video = document.getElementById("productPhotoVideo");
  const errorEl = document.getElementById("productPhotoCameraError");
  const errorText = document.getElementById("productPhotoCameraErrorText");
  const loadingEl = document.getElementById("productPhotoLoading");

  if (productPhotoStream) {
    productPhotoStream.getTracks().forEach((track) => track.stop());
    productPhotoStream = null;
  }

  if (loadingEl) loadingEl.classList.remove("hidden");
  if (errorEl) errorEl.classList.add("hidden");

  try {
    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      throw new Error("المتصفح لا يدعم الوصول المباشر لكاميرا الويب");
    }

    let constraints = {
      video: {
        facingMode: { ideal: facingMode },
        width: { ideal: 1280 },
        height: { ideal: 720 }
      },
      audio: false
    };

    try {
      productPhotoStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (_) {
      productPhotoStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: false });
    }

    if (video) {
      video.srcObject = productPhotoStream;
      await video.play();
    }
    if (loadingEl) loadingEl.classList.add("hidden");
  } catch (err) {
    console.error("Camera access error:", err);
    if (loadingEl) loadingEl.classList.add("hidden");
    if (errorEl) {
      errorEl.classList.remove("hidden");
      if (errorText) {
        errorText.innerText = "تعذر فتح الكاميرا: " + (err.message || "يرجى منح الإذن للمتصفح");
      }
    }
  }
}

async function switchProductCamera() {
  currentCameraFacingMode = currentCameraFacingMode === "environment" ? "user" : "environment";
  await startProductCamera(currentCameraFacingMode);
}

function closeProductPhotoModal() {
  const modal = document.getElementById("productPhotoModal");
  if (modal) modal.classList.remove("active");

  if (productPhotoStream) {
    productPhotoStream.getTracks().forEach((track) => track.stop());
    productPhotoStream = null;
  }

  const video = document.getElementById("productPhotoVideo");
  if (video) {
    video.srcObject = null;
  }
}

async function captureProductPhoto() {
  const video = document.getElementById("productPhotoVideo");
  const canvas = document.getElementById("productPhotoCanvas");
  if (!video || !canvas) return;

  const width = video.videoWidth || 640;
  const height = video.videoHeight || 480;

  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  ctx.drawImage(video, 0, 0, width, height);

  canvas.toBlob(async (blob) => {
    if (!blob) {
      alert("تعذر التقاط الصورة، يرجى المحاولة مرة أخرى.");
      return;
    }

    const file = new File([blob], `product_${Date.now()}.jpg`, { type: "image/jpeg" });

    closeProductPhotoModal();

    const mockInput = {
      files: [file],
      value: ""
    };

    await handleImageFileSelected(
      mockInput,
      activePhotoTarget.urlInputId,
      activePhotoTarget.previewImgId,
      activePhotoTarget.placeholderId
    );
  }, "image/jpeg", 0.9);
}

function clearProductImage(urlInputId, previewImgId, placeholderId) {
  const urlInput = document.getElementById(urlInputId);
  if (urlInput) urlInput.value = "";
  updateImagePreview(urlInputId, previewImgId, placeholderId);
}

async function handleImageFileSelected(fileInput, urlInputId, previewImgId, placeholderId) {
  if (!fileInput || !fileInput.files || fileInput.files.length === 0) return;
  const file = fileInput.files[0];

  const prefix = urlInputId.startsWith("modalEdit") ? "modalEdit" : "product";
  const statusEl = document.getElementById(`${prefix}ImageUploadStatus`);

  const showUploadStatus = (html, type = "loading") => {
    if (!statusEl) return;
    statusEl.className = `image-upload-status ${type}`;
    statusEl.innerHTML = html;
    statusEl.classList.remove("hidden");
  };

  const hideUploadStatus = () => {
    if (statusEl) statusEl.classList.add("hidden");
  };

  showUploadStatus('<i class="fa-solid fa-spinner fa-spin"></i> جاري تجهيز وضغط الصورة...', 'loading');

  try {
    // 1. Client-side Image Optimization via Canvas (scales to max 1000px WebP/JPEG)
    const compressedDataUrl = await compressImageFile(file, 1000, 0.82);
    const compressedBlob = dataURLtoBlob(compressedDataUrl);

    // 2. Try uploading to Supabase Storage bucket 'products'
    let finalImageUrl = compressedDataUrl;
    let uploadedToStorage = false;
    let storageErrorMessage = null;

    try {
      if (supabaseClient && supabaseClient.storage) {
        showUploadStatus('<i class="fa-solid fa-spinner fa-spin"></i> جاري رفع الصورة إلى سحابة التخزين...', 'loading');
        const cleanFileName = `prod_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;

        // Determine target store ID from UI
        const isModal = urlInputId.startsWith("modalEdit");
        const supplierSelect = document.getElementById(isModal ? "modalEditSupplier" : "productSupplier");
        const storeId = (supplierSelect && supplierSelect.value) ? supplierSelect.value : (suppliers[0]?.id || 'default');
        const authUser = (await supabaseClient.auth.getUser())?.data?.user;
        const userId = currentUser?.id || authUser?.id || 'admin';

        // Path standard: {userId}/products/{storeId}/{cleanFileName}
        const filePath = `${userId}/products/${storeId}/${cleanFileName}`;

        const { data: uploadData, error: uploadErr } = await supabaseClient.storage
          .from("products")
          .upload(filePath, compressedBlob, {
            contentType: 'image/jpeg',
            upsert: true
          });

        if (uploadErr) {
          console.error("Storage upload error:", uploadErr);
          storageErrorMessage = uploadErr.message || "فشل التحقق من صلاحيات التخزين";
        } else if (uploadData) {
          const { data: publicData } = supabaseClient.storage
            .from("products")
            .getPublicUrl(filePath);

          if (publicData && publicData.publicUrl) {
            finalImageUrl = publicData.publicUrl;
            uploadedToStorage = true;
          }
        }
      }
    } catch (storageErr) {
      console.warn("Storage upload fallback to compressed Data URL:", storageErr);
      storageErrorMessage = storageErr.message;
    }

    // 3. Set URL in input
    const urlInput = document.getElementById(urlInputId);
    if (urlInput) {
      urlInput.value = finalImageUrl;
    }

    // 4. Update preview box
    updateImagePreview(urlInputId, previewImgId, placeholderId);

    if (uploadedToStorage) {
      showUploadStatus(`
        <i class="fa-solid fa-circle-check"></i>
        <span>تم رفع الصورة بنجاح إلى سحابة التخزين (Supabase Storage)!</span>
      `, 'success');
      setTimeout(hideUploadStatus, 4000);
    } else {
      showUploadStatus(`
        <i class="fa-solid fa-triangle-exclamation"></i>
        <span>تحذير: تعذر رفع الصورة إلى سحابة التخزين (${storageErrorMessage || 'خطأ في صلاحيات Storage'}). يرجى التأكد من تشغيل صلاحية مدير المتجر في Supabase.</span>
      `, 'error');
    }

  } catch (err) {
    console.error("Image processing error:", err);
    showUploadStatus(`❌ تعذر معالجة الصورة: ${err.message}`, 'error');
    setTimeout(hideUploadStatus, 5000);
  } finally {
    fileInput.value = "";
  }
}

function dataURLtoBlob(dataurl) {
  const arr = dataurl.split(',');
  const mime = arr[0].match(/:(.*?);/)[1];
  const bstr = atob(arr[1]);
  let n = bstr.length;
  const u8arr = new Uint8Array(n);
  while (n--) {
    u8arr[n] = bstr.charCodeAt(n);
  }
  return new Blob([u8arr], { type: mime });
}

function compressImageFile(file, maxDimension = 1000, quality = 0.82, outputMime = "image/jpeg") {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        let width = img.width;
        let height = img.height;

        if (width > maxDimension || height > maxDimension) {
          if (width > height) {
            height = Math.round((height * maxDimension) / width);
            width = maxDimension;
          } else {
            width = Math.round((width * maxDimension) / height);
            height = maxDimension;
          }
        }

        const canvas = document.createElement("canvas");
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext("2d");
        ctx.drawImage(img, 0, 0, width, height);

        const dataUrl = canvas.toDataURL(outputMime, quality);
        resolve(dataUrl);
      };
      img.onerror = () => reject(new Error("فشل قراءة ملف الصورة"));
      img.src = e.target.result;
    };
    reader.onerror = () => reject(new Error("فشل فتح الملف من جهازك"));
    reader.readAsDataURL(file);
  });
}

// ----------------------------------------------------
// Product Gallery & Custom Specifications Helpers
// ----------------------------------------------------
function escapeHtml(str) {
  if (str === null || str === undefined) return "";
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function triggerGalleryUpload(inputId) {
  const el = document.getElementById(inputId);
  if (el) el.click();
}

function promptAddGalleryUrl(prefix) {
  const url = prompt("أدخل رابط الصورة الإضافية المباشر (https://...):");
  if (url && url.trim().startsWith("http")) {
    const list = prefix === "product" ? productGalleryUrls : modalEditGalleryUrls;
    list.push(url.trim());
    renderGalleryGrid(prefix);
  }
}

function removeGalleryImage(prefix, index) {
  const list = prefix === "product" ? productGalleryUrls : modalEditGalleryUrls;
  list.splice(index, 1);
  renderGalleryGrid(prefix);
}

function renderGalleryGrid(prefix) {
  const grid = document.getElementById(`${prefix}GalleryGrid`);
  if (!grid) return;
  const list = prefix === "product" ? productGalleryUrls : modalEditGalleryUrls;
  grid.innerHTML = list.map((url, idx) => `
    <div class="gallery-thumb-item">
      <img src="${url}" alt="صورة إضافية ${idx + 1}" onclick="window.open('${url}', '_blank')">
      <span class="gallery-thumb-badge">${idx + 1}</span>
      <button type="button" class="gallery-thumb-delete" onclick="removeGalleryImage('${prefix}', ${idx})" title="حذف هذه الصورة">
        <i class="fa-solid fa-xmark"></i>
      </button>
    </div>
  `).join("");
}

async function handleGalleryFilesSelected(fileInput, prefix) {
  const files = Array.from(fileInput.files || []);
  if (files.length === 0) return;

  const statusEl = document.getElementById(`${prefix}GalleryStatus`);
  const showStatus = (msg, type = 'loading') => {
    if (!statusEl) return;
    statusEl.innerHTML = msg;
    statusEl.className = `image-upload-status ${type}`;
    statusEl.classList.remove("hidden");
  };
  const hideStatus = () => {
    if (statusEl) statusEl.classList.add("hidden");
  };

  showStatus(`<i class="fa-solid fa-spinner fa-spin"></i> جاري تجهيز ورفع ${files.length} صورة إلى التخزين...`, 'loading');

  try {
    const authUser = (await supabaseClient.auth.getUser())?.data?.user;
    const userId = currentUser?.id || authUser?.id || 'admin';
    const isModal = prefix === "modalEdit";
    const supplierSelect = document.getElementById(isModal ? "modalEditSupplier" : "productSupplier");
    const storeId = (supplierSelect && supplierSelect.value) ? supplierSelect.value : (suppliers[0]?.id || 'default');

    const list = prefix === "product" ? productGalleryUrls : modalEditGalleryUrls;
    let successCount = 0;

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      showStatus(`<i class="fa-solid fa-spinner fa-spin"></i> جاري رفع الصورة (${i + 1} من ${files.length})...`, 'loading');

      try {
        const compressedDataUrl = await compressImageFile(file, 1000, 0.82);
        const compressedBlob = dataURLtoBlob(compressedDataUrl);
        const cleanFileName = `gallery_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
        const filePath = `${userId}/products/${storeId}/${cleanFileName}`;

        const { data: uploadData, error: uploadErr } = await supabaseClient.storage
          .from("products")
          .upload(filePath, compressedBlob, { contentType: 'image/jpeg', upsert: true });

        if (!uploadErr && uploadData) {
          const { data: publicData } = supabaseClient.storage.from("products").getPublicUrl(filePath);
          if (publicData && publicData.publicUrl) {
            list.push(publicData.publicUrl);
            successCount++;
          }
        } else {
          console.error("Gallery file upload error:", uploadErr);
        }
      } catch (fErr) {
        console.error("Error processing gallery file:", fErr);
      }
    }

    renderGalleryGrid(prefix);

    if (successCount > 0) {
      showStatus(`<i class="fa-solid fa-circle-check"></i> تم رفع ${successCount} صورة بنجاح إلى المعرض!`, 'success');
      setTimeout(hideStatus, 4000);
    } else {
      showStatus(`<i class="fa-solid fa-triangle-exclamation"></i> تعذر رفع الصور. يرجى التأكد من تشغيل صلاحية مدير المتجر في Supabase.`, 'error');
      setTimeout(hideStatus, 5000);
    }
  } catch (err) {
    console.error("Gallery upload error:", err);
    showStatus(`❌ حدث خطأ أثناء رفع صور المعرض: ${err.message}`, 'error');
  } finally {
    fileInput.value = "";
  }
}

// Color map for visual dots in options chips
const OPTION_COLOR_HEX_MAP = {
  'أسود': '#111827', 'black': '#111827',
  'أبيض': '#ffffff', 'white': '#ffffff',
  'أحمر': '#ef4444', 'red': '#ef4444',
  'أزرق': '#3b82f6', 'blue': '#3b82f6',
  'كحلي': '#1e3a8a', 'navy': '#1e3a8a',
  'أخضر': '#22c55e', 'green': '#22c55e',
  'أصفر': '#eab308', 'yellow': '#eab308',
  'برتقالي': '#f97316', 'orange': '#f97316',
  'رمادي': '#6b7280', 'gray': '#6b7280', 'grey': '#6b7280',
  'بيج': '#d2b48c', 'beige': '#d2b48c',
  'بني': '#78350f', 'brown': '#78350f',
  'فضي': '#94a3b8', 'silver': '#94a3b8',
  'ذهبي': '#d97706', 'gold': '#d97706',
  'وردي': '#ec4899', 'pink': '#ec4899',
  'بنفسجي': '#8b5cf6', 'purple': '#8b5cf6'
};

function detectOptionType(key) {
  if (!key) return 'color';
  const k = key.toLowerCase().trim();
  if (k.includes('لون') || k.includes('color') || k.includes('ألوان')) return 'color';
  if (k.includes('مقاس') || k.includes('size')) return 'size';
  if (k.includes('وزن') || k.includes('حجم') || k.includes('weight') || k.includes('volume')) return 'weight';
  if (k.includes('سعة') || k.includes('capacity') || k.includes('ذاكرة')) return 'capacity';
  return 'custom';
}

function addCustomSpecRow(prefix, key = '', value = '', forcedType = null, skipSync = false) {
  const container = document.getElementById(`${prefix}SpecsContainer`);
  if (!container) return;

  // Determine initial option type
  let initialType = forcedType;
  if (!initialType) {
    initialType = key ? detectOptionType(key) : 'color';
  }

  // If no key given, default to the type's Arabic name
  if (!key) {
    if (initialType === 'color') key = 'اللون';
    else if (initialType === 'size') key = 'المقاس';
    else if (initialType === 'weight') key = 'الحجم / الوزن';
    else if (initialType === 'capacity') key = 'السعة';
    else key = '';
  }

  // Parse initial values (could be array or comma-separated string)
  let values = [];
  if (Array.isArray(value)) {
    values = value.map(v => String(v || '').trim()).filter(Boolean);
  } else if (typeof value === 'string' && value.trim()) {
    values = value.split(/[,،]/).map(v => v.trim()).filter(Boolean);
  }

  const row = document.createElement("div");
  row.className = "spec-row option-row-card";

  row.innerHTML = `
    <div class="option-card-header">
      <select class="option-type-select" title="نوع خيار العميل">
        <option value="color" ${initialType === 'color' ? 'selected' : ''}>🎨 اللون (Colors)</option>
        <option value="size" ${initialType === 'size' ? 'selected' : ''}>👕 المقاس (Sizes)</option>
        <option value="weight" ${initialType === 'weight' ? 'selected' : ''}>⚖️ الحجم / الوزن (Volume/Weight)</option>
        <option value="capacity" ${initialType === 'capacity' ? 'selected' : ''}>💾 السعة / الذاكرة (Capacity)</option>
        <option value="custom" ${initialType === 'custom' ? 'selected' : ''}>⚙️ خيار مخصص...</option>
      </select>
      <input type="text" class="spec-key option-name-input" placeholder="اسم الخيار (مثال: اللون، المقاس)..." value="${escapeHtml(key)}">
      <button type="button" class="spec-row-delete-btn option-delete-btn" title="حذف هذا الخيار بالكامل">
        <i class="fa-solid fa-trash-can"></i>
      </button>
    </div>

    <!-- Presets bar for quick addition -->
    <div class="option-presets-bar"></div>

    <!-- Chips / Tags container -->
    <div class="option-chips-container"></div>

    <!-- Input to add custom or typed values -->
    <div class="option-add-value-group">
      <input type="text" class="option-add-value-input" placeholder="اكتب قيمة واضغط Enter (أو الصق قيماً مفصولة بفاصلة: أحمر, أزرق)...">
      <button type="button" class="btn btn-secondary btn-sm btn-add-val">
        <i class="fa-solid fa-plus"></i> <span>إضافة</span>
      </button>
    </div>

    <!-- Hidden input holding comma-separated string for 100% backward compatibility -->
    <input type="hidden" class="spec-val" value="${escapeHtml(values.join(', '))}">
  `;

  // Internal state for this row's values
  let currentValues = [...values];
  let currentType = initialType;

  const typeSelect = row.querySelector(".option-type-select");
  const nameInput = row.querySelector(".spec-key");
  const deleteBtn = row.querySelector(".option-delete-btn");
  const presetsBar = row.querySelector(".option-presets-bar");
  const chipsContainer = row.querySelector(".option-chips-container");
  const addValueInput = row.querySelector(".option-add-value-input");
  const addValueBtn = row.querySelector(".btn-add-val");
  const hiddenValInput = row.querySelector(".spec-val");

  let isInitialRender = true;
  const syncValues = () => {
    hiddenValInput.value = currentValues.join(", ");
    if (!(skipSync && isInitialRender)) {
      syncVariantsTable(prefix);
    }
  };

  const renderChips = () => {
    chipsContainer.innerHTML = "";
    if (currentValues.length === 0) {
      chipsContainer.innerHTML = `<span style="font-size:0.8rem;color:#94a3b8;font-style:italic;">لم يتم إضافة أي خيارات بعد. اضغط على الأزرار السريعة بالأعلى أو اكتب في الحقل أدناه.</span>`;
      syncValues();
      return;
    }

    currentValues.forEach((val, idx) => {
      const chip = document.createElement("span");
      chip.className = "option-value-chip";

      let colorDotHtml = "";
      const hex = OPTION_COLOR_HEX_MAP[val.toLowerCase()] || (val.startsWith("#") ? val : null);
      if (hex) {
        colorDotHtml = `<span class="color-dot" style="background-color: ${hex};"></span>`;
      }

      chip.innerHTML = `
        ${colorDotHtml}
        <span>${escapeHtml(val)}</span>
        <button type="button" class="chip-remove-btn" title="حذف هذا الخيار">✕</button>
      `;

      chip.querySelector(".chip-remove-btn").addEventListener("click", () => {
        currentValues.splice(idx, 1);
        renderChips();
      });

      chipsContainer.appendChild(chip);
    });

    syncValues();
  };

  const addValues = (rawStr) => {
    if (!rawStr) return;
    const items = rawStr.split(/[,،]/).map(s => s.trim()).filter(Boolean);
    let changed = false;
    items.forEach(item => {
      if (!currentValues.includes(item)) {
        currentValues.push(item);
        changed = true;
      }
    });
    if (changed) {
      renderChips();
    }
  };

  const renderPresets = () => {
    presetsBar.innerHTML = "";

    if (currentType === "color") {
      const colors = ['أسود', 'أبيض', 'أحمر', 'أزرق', 'كحلي', 'أخضر', 'أصفر', 'رمادي', 'بيج', 'بني', 'فضي', 'ذهبي'];
      presetsBar.innerHTML = `
        <span class="presets-label"><i class="fa-solid fa-palette"></i> ألوان سريعة:</span>
        ${colors.map(c => `
          <button type="button" class="preset-chip-btn" data-val="${c}">
            <span class="color-dot" style="background:${OPTION_COLOR_HEX_MAP[c]}"></span>
            <span>${c}</span>
          </button>
        `).join("")}
        <div class="color-picker-wrapper">
          <input type="color" class="color-picker-input" value="#0284c7" title="اختر درجة لون دقيقة">
          <button type="button" class="btn btn-outline btn-sm btn-add-color-picker" style="padding:2px 8px;font-size:0.75rem;">
            + إضافة اللون
          </button>
        </div>
      `;

      presetsBar.querySelectorAll(".preset-chip-btn").forEach(btn => {
        btn.addEventListener("click", () => addValues(btn.dataset.val));
      });

      const pickerInput = presetsBar.querySelector(".color-picker-input");
      const addColorBtn = presetsBar.querySelector(".btn-add-color-picker");
      if (addColorBtn && pickerInput) {
        addColorBtn.addEventListener("click", () => addValues(pickerInput.value));
      }

    } else if (currentType === "size") {
      const sizes = ['S', 'M', 'L', 'XL', 'XXL', '3XL', '38', '39', '40', '41', '42', '43', '44', '45'];
      presetsBar.innerHTML = `
        <span class="presets-label"><i class="fa-solid fa-ruler-combined"></i> مقاسات سريعة:</span>
        ${sizes.map(s => `
          <button type="button" class="preset-chip-btn" data-val="${s}">${s}</button>
        `).join("")}
      `;
      presetsBar.querySelectorAll(".preset-chip-btn").forEach(btn => {
        btn.addEventListener("click", () => addValues(btn.dataset.val));
      });

    } else if (currentType === "weight") {
      const weights = ['250 مل', '500 مل', '1 لتر', '250 جم', '500 جم', '1 كجم'];
      presetsBar.innerHTML = `
        <span class="presets-label"><i class="fa-solid fa-weight-scale"></i> أحجام وأوزان:</span>
        ${weights.map(w => `
          <button type="button" class="preset-chip-btn" data-val="${w}">${w}</button>
        `).join("")}
      `;
      presetsBar.querySelectorAll(".preset-chip-btn").forEach(btn => {
        btn.addEventListener("click", () => addValues(btn.dataset.val));
      });

    } else if (currentType === "capacity") {
      const capacities = ['32GB', '64GB', '128GB', '256GB', '512GB', '1TB'];
      presetsBar.innerHTML = `
        <span class="presets-label"><i class="fa-solid fa-microchip"></i> سعات تخزين:</span>
        ${capacities.map(c => `
          <button type="button" class="preset-chip-btn" data-val="${c}">${c}</button>
        `).join("")}
      `;
      presetsBar.querySelectorAll(".preset-chip-btn").forEach(btn => {
        btn.addEventListener("click", () => addValues(btn.dataset.val));
      });

    } else {
      presetsBar.innerHTML = `<span class="presets-label" style="font-weight:normal;color:#64748b;">💡 اكتب القيم المخصصة في الحقل أدناه مفصولة بفاصلة واضغط إضافة.</span>`;
    }
  };

  typeSelect.addEventListener("change", () => {
    currentType = typeSelect.value;
    if (currentType === "color" && (!nameInput.value.trim() || nameInput.value === "المقاس" || nameInput.value === "الحجم / الوزن" || nameInput.value === "السعة")) {
      nameInput.value = "اللون";
    } else if (currentType === "size" && (!nameInput.value.trim() || nameInput.value === "اللون" || nameInput.value === "الحجم / الوزن" || nameInput.value === "السعة")) {
      nameInput.value = "المقاس";
    } else if (currentType === "weight" && (!nameInput.value.trim() || nameInput.value === "اللون" || nameInput.value === "المقاس" || nameInput.value === "السعة")) {
      nameInput.value = "الحجم / الوزن";
    } else if (currentType === "capacity" && (!nameInput.value.trim() || nameInput.value === "اللون" || nameInput.value === "المقاس" || nameInput.value === "الحجم / الوزن")) {
      nameInput.value = "السعة";
    } else if (currentType === "custom" && (nameInput.value === "اللون" || nameInput.value === "المقاس" || nameInput.value === "الحجم / الوزن" || nameInput.value === "السعة")) {
      nameInput.value = "";
      nameInput.focus();
    }
    renderPresets();
  });

  deleteBtn.addEventListener("click", () => {
    row.remove();
    syncVariantsTable(prefix);
  });

  nameInput.addEventListener("change", () => syncVariantsTable(prefix));

  const handleAddFromInput = () => {
    const val = addValueInput.value.trim();
    if (val) {
      addValues(val);
      addValueInput.value = "";
    }
    addValueInput.focus();
  };

  addValueBtn.addEventListener("click", handleAddFromInput);
  addValueInput.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      handleAddFromInput();
    }
  });

  renderPresets();
  renderChips();
  isInitialRender = false;

  container.appendChild(row);
  if (!skipSync) {
    syncVariantsTable(prefix);
  }
}

function getCustomSpecsFromContainer(prefix) {
  const container = document.getElementById(`${prefix}SpecsContainer`);
  if (!container) return {};
  const specs = {};
  const rows = container.querySelectorAll(".spec-row");
  rows.forEach(r => {
    const k = r.querySelector(".spec-key")?.value.trim();
    const v = r.querySelector(".spec-val")?.value.trim();
    if (k && v) {
      specs[k] = v;
    }
  });
  return specs;
}

function getVariantGroupsFromContainer(prefix) {
  const container = document.getElementById(`${prefix}SpecsContainer`);
  if (!container) return [];
  const groups = [];
  const rows = container.querySelectorAll(".spec-row");
  rows.forEach((r, idx) => {
    const k = r.querySelector(".spec-key")?.value.trim();
    const v = r.querySelector(".spec-val")?.value.trim();
    const typeSelect = r.querySelector(".option-type-select");
    const type = typeSelect ? typeSelect.value : detectOptionType(k);
    if (k && v) {
      const values = v.split(/[,،]/).map(s => s.trim()).filter(Boolean);
      if (values.length > 0) {
        groups.push({
          id: `vg_${Date.now()}_${idx}`,
          name: k,
          type: type || 'custom',
          is_required: false,
          sort_order: idx,
          is_active: true,
          created_at: new Date().toISOString(),
          options: values.map((val, vIdx) => ({
            id: `opt_${Date.now()}_${idx}_${vIdx}`,
            name: k,
            value: val,
            sort_order: vIdx,
            is_active: true,
            created_at: new Date().toISOString()
          }))
        });
      }
    }
  });
  return groups;
}

const arabicVariantLetters = {
  ا: "A", ب: "B", ت: "T", ث: "TH", ج: "G", ح: "H", خ: "KH",
  د: "D", ذ: "DH", ر: "R", ز: "Z", س: "S", ش: "SH", ص: "S",
  ض: "D", ط: "T", ظ: "Z", ع: "A", غ: "GH", ف: "F", ق: "Q",
  ك: "K", ل: "L", م: "M", ن: "N", ه: "H", ة: "H", و: "W",
  ي: "Y", ى: "Y", ء: "A"
};

// These two established option codes use different spelling from the letter map.
const arabicVariantSpellings = new Map([["جملي", "GML"], ["جبنة", "JBN"]]);

const variantColorCodes = new Map([
  ["اسود", "BLK"], ["black", "BLK"], ["ابيض", "WHT"], ["white", "WHT"],
  ["احمر", "RED"], ["red", "RED"], ["ازرق", "BLU"], ["blue", "BLU"],
  ["اخضر", "GRN"], ["green", "GRN"], ["اصفر", "YLW"], ["yellow", "YLW"],
  ["كحلي", "NVY"], ["navy", "NVY"], ["رمادي", "GRY"], ["رصاصي", "GRY"],
  ["gray", "GRY"], ["grey", "GRY"], ["بني", "BRN"], ["brown", "BRN"],
  ["بيج", "BEG"], ["beige", "BEG"], ["ذهبي", "GLD"], ["gold", "GLD"],
  ["فضي", "SLV"], ["silver", "SLV"]
]);

const variantUnits = {
  مل: "ML", ملليلتر: "ML", مليلتر: "ML", ml: "ML",
  لتر: "L", l: "L",
  جم: "G", جرام: "G", غرام: "G", g: "G",
  كجم: "KG", كيلو: "KG", كيلوجرام: "KG", "كيلو جرام": "KG", kg: "KG",
  جيجا: "GB", gb: "GB", تيرا: "TB", tb: "TB",
  وات: "W", w: "W", سم: "CM", cm: "CM"
};
const variantMeasurementPattern = new RegExp(
  "(?:^|[^\\p{L}\\p{N}.])(\\d+(?:\\.\\d+)?)\\s*(" + Object.keys(variantUnits).join("|") + ")(?![\\p{L}\\p{N}])",
  "u"
);

function normalizeVariantOptionText(text) {
  return String(text ?? "").normalize("NFKD").toLowerCase()
    .replace(/[\p{M}ـ]/gu, "").replace(/\s+/g, " ").trim();
}

function transliterateArabicToCode(text) {
  const words = normalizeVariantOptionText(text).replace(/(^|[^\p{L}])ال(?=\p{Script=Arabic})/gu, "$1");
  const special = arabicVariantSpellings.get(words);
  if (special) return special;
  return Array.from(words, char => arabicVariantLetters[char] || (/[a-z]/.test(char) ? char.toUpperCase() : ""))
    .join("").slice(0, 4);
}

function formatVariantOptionCode(rawValue) {
  const value = normalizeVariantOptionText(rawValue)
    .replace(/[٠-٩]/g, digit => String(digit.charCodeAt(0) - "٠".charCodeAt(0)))
    .replace(/[۰-۹]/g, digit => String(digit.charCodeAt(0) - "۰".charCodeAt(0)))
    .replace(/٫/g, ".").replace(/٬/g, "");
  const size = value.replace(/^(?:مقاس|size)\s+/, "");
  if (/^(?:[sml]|x+s|x+l|\d+xl|\d+(?:\.\d+)?)$/.test(size)) return size.toUpperCase();

  const measurement = value.match(variantMeasurementPattern);
  if (measurement) return measurement[1] + variantUnits[measurement[2]];

  const term = value.replace(/^ال(?=\p{Script=Arabic})/u, "");
  const color = variantColorCodes.get(term);
  if (color) return color;
  if (/^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/.test(value)) return value.slice(1).toUpperCase();
  return /\p{Script=Arabic}/u.test(term)
    ? transliterateArabicToCode(value)
    : value.replace(/[^a-z]/g, "").slice(0, 4).toUpperCase();
}

function buildVariantChildSku(baseSku, selectedOptions, usedSkus = new Set()) {
  const optionCodes = selectedOptions.map(option => formatVariantOptionCode(option?.value ?? option) || "OPT");
  const base = [baseSku.trim() || "VAR", ...optionCodes].join("-");
  let sku = base;
  for (let suffix = 2; usedSkus.has(sku.toUpperCase()); suffix++) {
    sku = `${base}-${suffix}`;
  }
  usedSkus.add(sku.toUpperCase());
  return sku;
}

function refreshVariantSkus(prefix, editingSku = null) {
  const tbody = document.getElementById(`${prefix}VariantsTableBody`);
  const baseSku = document.getElementById(`${prefix}Sku`)?.value.trim() ||
    document.getElementById(`${prefix}Barcode`)?.value.trim() || "";
  const usedSkus = new Set();
  const automaticRows = [];
  for (const tr of tbody?.rows || []) {
    const input = tr.querySelector(".var-sku");
    const key = input.value.trim().toUpperCase();
    input.setCustomValidity("");
    if (tr.dataset.skuManual === "true" && key) {
      if (usedSkus.has(key)) input.setCustomValidity("كود التركيبة مكرر. اكتب كودًا مختلفًا أو امسحه لتوليد كود تلقائي.");
      usedSkus.add(key);
    } else {
      automaticRows.push(tr);
    }
  }
  for (const tr of automaticRows) {
    const input = tr.querySelector(".var-sku");
    const sku = buildVariantChildSku(baseSku, JSON.parse(tr.dataset.selectedOptions), usedSkus);
    if (input !== editingSku) input.value = sku;
  }
}

// Generate Cartesian product of variant groups and render the Variants Matrix Table
function syncVariantsTable(prefix, existingVariants = null) {
  const section = document.getElementById(`${prefix}VariantsMatrixSection`);
  const tbody = document.getElementById(`${prefix}VariantsTableBody`);
  if (!section || !tbody) return;

  const groups = getVariantGroupsFromContainer(prefix);
  if (groups.length === 0) {
    tbody.innerHTML = "";
    section.classList.add("hidden");
    return;
  }

  section.classList.remove("hidden");
  const baseBarcode = document.getElementById(`${prefix}Barcode`)?.value.trim() || "";

  // Build map of existing variant values (either from passed existingVariants or current DOM)
  const preservedMap = new Map();
  if (Array.isArray(existingVariants)) {
    existingVariants.forEach((v, index) => {
      if (v && Array.isArray(v.selected_options)) {
        const key = v.selected_options.map(o => `${o.name}:${o.value}`).join('|');
        preservedMap.set(key, {
          id: v.id,
          price: v.price ?? '',
          stock_quantity: v.stock_quantity ?? '',
          sku: v.sku || '',
          skuManual: v.sku_is_manual ?? Boolean(v.sku && v.sku !== `VAR-${index + 1}` &&
            (!baseBarcode || v.sku !== `${baseBarcode}-${index + 1}`)),
          image_url: v.image_url || '',
          is_active: v.is_active !== false,
          created_at: v.created_at || new Date().toISOString()
        });
      }
    });
  } else {
    tbody.querySelectorAll("tr").forEach(tr => {
      const key = tr.dataset.comboKey;
      if (key) {
        preservedMap.set(key, {
          id: tr.dataset.variantId || '',
          price: tr.querySelector(".var-price")?.value || '',
          stock_quantity: tr.querySelector(".var-stock")?.value || '',
          sku: tr.querySelector(".var-sku")?.value || '',
          skuManual: tr.dataset.skuManual === "true",
          image_url: tr.querySelector(".var-img")?.value || '',
          is_active: tr.querySelector(".var-active")?.checked !== false,
          created_at: tr.dataset.createdAt || new Date().toISOString()
        });
      }
    });
  }

  // Cartesian product of groups
  let combinations = [[]];
  for (const group of groups) {
    const next = [];
    for (const combo of combinations) {
      for (const opt of group.options) {
        next.push([...combo, {
          id: opt.id,
          name: group.name,
          value: opt.value,
          sort_order: opt.sort_order,
          is_active: true,
          created_at: opt.created_at
        }]);
      }
    }
    combinations = next;
  }

  const basePrice = document.getElementById(`${prefix}Price`)?.value || '';
  const baseStock = document.getElementById(`${prefix}Stock`)?.value || '0';

  tbody.innerHTML = "";
  combinations.forEach((selectedOptions, idx) => {
    const comboKey = selectedOptions.map(o => `${o.name}:${o.value}`).join('|');
    const saved = preservedMap.get(comboKey);

    const varId = saved?.id || `var_${Date.now()}_${idx}`;
    const priceVal = saved ? saved.price : basePrice;
    const stockVal = saved ? saved.stock_quantity : baseStock;
    const skuVal = saved?.skuManual ? saved.sku : "";
    const imgVal = saved?.image_url || '';
    const isActive = saved ? saved.is_active : true;
    const createdAt = saved?.created_at || new Date().toISOString();

    const badgesHtml = selectedOptions.map(o => {
      const hex = OPTION_COLOR_HEX_MAP[o.value.toLowerCase()] || (o.value.startsWith("#") ? o.value : null);
      const dot = hex ? `<span class="color-dot" style="background:${hex};"></span>` : '';
      return `<span class="variant-combo-pill">${dot}<span>${escapeHtml(o.name)}: ${escapeHtml(o.value)}</span></span>`;
    }).join("");

    const tr = document.createElement("tr");
    tr.dataset.comboKey = comboKey;
    tr.dataset.variantId = varId;
    tr.dataset.createdAt = createdAt;
    tr.dataset.selectedOptions = JSON.stringify(selectedOptions);
    tr.dataset.skuManual = String(Boolean(saved?.skuManual));

    tr.innerHTML = `
      <td><div class="variant-combo-badge">${badgesHtml}</div></td>
      <td style="min-width:95px;"><input type="number" step="0.5" class="var-price" placeholder="السعر" value="${escapeHtml(priceVal)}"></td>
      <td style="min-width:80px;"><input type="number" class="var-stock" placeholder="الكمية" value="${escapeHtml(stockVal)}"></td>
      <td style="min-width:130px;"><input type="text" class="var-sku" placeholder="SKU / باركود" value="${escapeHtml(skuVal)}"></td>
      <td>
        <div class="variant-img-cell">
          <img class="variant-thumb-preview ${imgVal ? '' : 'hidden'}" style="width:32px;height:32px" src="${escapeHtml(imgVal || 'logo.png')}" alt="صورة الخيار">
          <input type="url" class="var-img" placeholder="رابط الصورة..." value="${escapeHtml(imgVal)}">
          <input type="file" accept="image/*" class="hidden var-file-input">
          <button type="button" class="variant-upload-btn" title="رفع صورة لهذا الخيار"><i class="fa-solid fa-upload"></i></button>
          <button type="button" class="variant-upload-btn var-fetch-image" title="جلب صورة هذا الخيار تلقائياً" aria-label="جلب صورة هذا الخيار تلقائياً">
            <i class="fa-solid fa-magnifying-glass" aria-hidden="true"></i>
          </button>
        </div>
        <small class="var-image-status" role="status"></small>
      </td>
      <td style="text-align:center;"><input type="checkbox" class="var-active" ${isActive ? 'checked' : ''}></td>
    `;

    const skuInput = tr.querySelector(".var-sku");
    skuInput.addEventListener("input", () => {
      tr.dataset.skuManual = String(Boolean(skuInput.value.trim()));
      refreshVariantSkus(prefix, skuInput);
    });
    skuInput.addEventListener("change", () => refreshVariantSkus(prefix));

    const imgInput = tr.querySelector(".var-img");
    const thumbImg = tr.querySelector(".variant-thumb-preview");
    const fileInput = tr.querySelector(".var-file-input");
    const uploadBtn = tr.querySelector(".variant-upload-btn:not(.var-fetch-image)");
    const fetchBtn = tr.querySelector(".var-fetch-image");

    imgInput.addEventListener("input", () => {
      const url = imgInput.value.trim();
      if (/^(?:https?:\/\/|data:)/i.test(url)) {
        thumbImg.src = url;
        thumbImg.classList.remove("hidden");
      } else {
        thumbImg.classList.add("hidden");
      }
    });

    uploadBtn.addEventListener("click", () => fileInput.click());
    fileInput.addEventListener("change", () => uploadVariantImage(fileInput, imgInput, thumbImg, prefix));
    fetchBtn.addEventListener("click", () => autoFetchSingleVariantImage(tr, prefix));

    tbody.appendChild(tr);
  });
  refreshVariantSkus(prefix);
}

function getVariantImageLookup(row, prefix) {
  const barcode = cleanBarcode(row.querySelector(".var-sku").value);
  if (/^\d{8,}$/.test(barcode)) return { barcode };

  const productName = document.getElementById(`${prefix}Name`).value.trim();
  if (!productName) return null;
  const selectedOptions = JSON.parse(row.dataset.selectedOptions || "[]");
  const variantLabel = selectedOptions.map(option => option.value).filter(Boolean).join(" - ");
  return { query: [productName, variantLabel].filter(Boolean).join(" ") };
}

async function autoFetchSingleVariantImage(row, prefix) {
  const button = row.querySelector(".var-fetch-image");
  if (!row.isConnected || button.disabled) return "skipped";

  const imageInput = row.querySelector(".var-img");
  const status = row.querySelector(".var-image-status");
  const lookup = getVariantImageLookup(row, prefix);
  if (!lookup) {
    status.textContent = "اكتب اسم المنتج أولاً.";
    return "failed";
  }

  const initialImage = imageInput.value;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);
  button.disabled = true;
  status.textContent = "جارٍ البحث عن الصورة…";
  try {
    const product = await requestGoogleProductLookup(lookup, controller.signal);
    if (!row.isConnected || imageInput.value !== initialImage ||
        JSON.stringify(getVariantImageLookup(row, prefix)) !== JSON.stringify(lookup)) {
      status.textContent = "";
      return "skipped";
    }
    const imageUrl = typeof product?.image_url === "string" ? product.image_url.trim() : "";
    if (!/^https?:\/\//i.test(imageUrl)) {
      status.textContent = "لم نجد صورة لهذا الخيار.";
      return "missing";
    }
    imageInput.value = imageUrl;
    imageInput.dispatchEvent(new Event("input"));
    status.textContent = "تم جلب الصورة.";
    return "found";
  } catch (error) {
    console.warn("Variant image lookup failed:", error);
    status.textContent = "تعذّر جلب الصورة.";
    return "failed";
  } finally {
    clearTimeout(timeout);
    button.disabled = false;
  }
}

async function autoFetchAllVariantImages(prefix) {
  const tbody = document.getElementById(`${prefix}VariantsTableBody`);
  const button = document.getElementById(`${prefix}FetchVariantImages`);
  const status = document.getElementById(`${prefix}VariantImageStatus`);
  if (button.disabled) return;

  const primaryImage = document.getElementById(`${prefix}ImageUrl`).value.trim();
  const needsLookup = row => {
    const imageUrl = row.querySelector(".var-img").value.trim();
    return !imageUrl || imageUrl === primaryImage;
  };
  const rows = Array.from(tbody.rows).filter(needsLookup);
  if (rows.length === 0) {
    status.textContent = "جميع الخيارات لها صور خاصة بها.";
    return;
  }

  button.disabled = true;
  const counts = { found: 0, missing: 0, failed: 0, skipped: 0 };
  try {
    for (const [index, row] of rows.entries()) {
      status.textContent = `جارٍ البحث عن صور الخيارات (${index + 1} من ${rows.length})…`;
      const result = needsLookup(row) ? await autoFetchSingleVariantImage(row, prefix) : "skipped";
      counts[result]++;
    }
    const summary = [`تم جلب ${counts.found} من ${rows.length}.`];
    if (counts.missing) summary.push(`بدون نتائج: ${counts.missing}.`);
    if (counts.failed) summary.push(`تعذّر الجلب: ${counts.failed}.`);
    if (counts.skipped) summary.push(`تم تخطي: ${counts.skipped}.`);
    status.textContent = summary.join(" ");
  } finally {
    button.disabled = false;
  }
}

function variantsWithPrimaryImage(variants, primaryImageUrl) {
  if (!variants.length) return null;
  if (!primaryImageUrl && variants.some(variant => !variant.image_url)) {
    throw new Error("أضف صورة رئيسية للمنتج أو صورة لكل خيار قبل الحفظ.");
  }
  return variants.map(variant => variant.image_url ? variant : { ...variant, image_url: primaryImageUrl });
}

function applyBaseValuesToVariants(prefix) {
  const tbody = document.getElementById(`${prefix}VariantsTableBody`);
  if (!tbody) return;
  const basePrice = document.getElementById(`${prefix}Price`)?.value || '';
  const baseStock = document.getElementById(`${prefix}Stock`)?.value || '';
  tbody.querySelectorAll("tr").forEach(tr => {
    const pInput = tr.querySelector(".var-price");
    const sInput = tr.querySelector(".var-stock");
    if (pInput && basePrice) pInput.value = basePrice;
    if (sInput && baseStock !== '') sInput.value = baseStock;
  });
  refreshVariantSkus(prefix);
}

async function uploadVariantImage(fileInput, urlInput, thumbImg, prefix) {
  const file = fileInput.files && fileInput.files[0];
  if (!file) return;

  try {
    const compressedDataUrl = await compressImageFile(file, 800, 0.82);
    const compressedBlob = dataURLtoBlob(compressedDataUrl);
    const authUser = (await supabaseClient.auth.getUser())?.data?.user;
    const userId = currentUser?.id || authUser?.id || 'admin';
    const isModal = prefix === "modalEdit";
    const supplierSelect = document.getElementById(isModal ? "modalEditSupplier" : "productSupplier");
    const storeId = (supplierSelect && supplierSelect.value) ? supplierSelect.value : (suppliers[0]?.id || 'default');

    const cleanFileName = `var_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.jpg`;
    const filePath = `${userId}/products/${storeId}/${cleanFileName}`;

    const { data: uploadData, error: uploadErr } = await supabaseClient.storage
      .from("products")
      .upload(filePath, compressedBlob, { contentType: 'image/jpeg', upsert: true });

    if (uploadErr) {
      throw new Error(uploadErr.message);
    }

    if (uploadData) {
      const { data: publicData } = supabaseClient.storage.from("products").getPublicUrl(filePath);
      if (publicData && publicData.publicUrl) {
        urlInput.value = publicData.publicUrl;
        thumbImg.src = publicData.publicUrl;
        thumbImg.classList.remove("hidden");
      }
    }
  } catch (err) {
    console.error("Variant image upload error:", err);
    alert(`❌ تعذر رفع صورة الخيار: ${err.message}`);
  } finally {
    fileInput.value = "";
  }
}

function getVariantsFromContainer(prefix, productId = '') {
  const tbody = document.getElementById(`${prefix}VariantsTableBody`);
  if (!tbody) return [];
  refreshVariantSkus(prefix);
  const variants = [];
  const nowIso = new Date().toISOString();

  tbody.querySelectorAll("tr").forEach((tr, idx) => {
    const selectedOptions = JSON.parse(tr.dataset.selectedOptions || "[]");
    if (selectedOptions.length === 0) return;

    const priceRaw = parseFloat(tr.querySelector(".var-price")?.value);
    const stockRaw = parseInt(tr.querySelector(".var-stock")?.value, 10);
    const skuInput = tr.querySelector(".var-sku");
    if (!skuInput.validity.valid) throw new Error(skuInput.validationMessage);
    const imgRaw = (tr.querySelector(".var-img")?.value || "").trim();
    const isActive = tr.querySelector(".var-active")?.checked !== false;

    variants.push({
      id: tr.dataset.variantId || `var_${Date.now()}_${idx}`,
      product_id: productId || '',
      selected_options: selectedOptions,
      sku: skuInput.value.trim(),
      sku_is_manual: tr.dataset.skuManual === "true",
      price: isNaN(priceRaw) ? null : priceRaw,
      stock_quantity: isNaN(stockRaw) ? null : stockRaw,
      image_url: (imgRaw && !imgRaw.startsWith("data:")) ? imgRaw : null,
      is_active: isActive,
      created_at: tr.dataset.createdAt || nowIso,
      updated_at: nowIso
    });
  });

  return variants;
}


// ============================================================
// 🤖 SMART AUTO-FILL from Product Name
// ============================================================

// Known brand patterns (Arabic & International)
const KNOWN_BRANDS = [
  // إلكترونيات & تقنية
  'Samsung','Apple','Huawei','Xiaomi','Oppo','Vivo','Nokia','Sony','LG','Panasonic',
  'Philips','HP','Dell','Lenovo','Asus','Acer','Canon','Nikon','JBL','Bose','Anker',
  // بقالة & منتجات غذائية مصرية
  'عبور لاند','Obour Land','المراعي','Almarai','بيتي','Bettys','كادبوري','Cadbury',
  'نستلة','Nestle','يونيليفر','Unilever','هاينز','Heinz','بونجر','Peugeot',
  'برنامج','Americana','أميريكانا','بافاريا','Bavaria','كوكاكولا','Coca-Cola','بيبسي','Pepsi',
  'رويال','Royal','شيبسي','Chipsy','ليز','Lays','ميرندا','Mirinda','فانتا','Fanta',
  'Juhayna','جهينة','Dina Farms','مزرعة دينا','Domty','دومتي','Seoudi','السيودي',
  // ملابس
  'Nike','Adidas','Puma','Zara','H&M','Mango','Levi\'s','Calvin Klein','Gucci','Louis Vuitton',
  // رعاية شخصية
  'P&G','Procter','Dove','Nivea','Colgate','Oral-B','Head & Shoulders','Pantene',
  // أخرى
  'IKEA','Bosch','Siemens','Ariston','Zanussi','Kiriazi','كيريازي','Fresh','فريش',
  'Tornado','تورنيدو','Unionaire','يونيون','Olympic','أوليمبيك'
];

const BRAND_REGEX = new RegExp(
  '\\b(' + KNOWN_BRANDS.map(b => b.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')).join('|') + ')\\b',
  'i'
);

// Size/weight patterns
const SIZE_PATTERNS = [
  /\b(\d+(?:\.\d+)?)\s*(كيلو جرام|كيلوجرام|كجم|kg|KG)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(جرام|غرام|gr|g|GM)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(ملي لتر|مل|ml|ML)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(لتر|lt|ltr|L)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(GB|جيجا|TB|تيرا|MB|ميجا)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(واط|Watt|W)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(بوصة|inch|"|in)\b/i,
  /\b(\d+(?:\.\d+)?)\s*(قطعة|pcs|pieces|علبة|pack|باكيت)\b/i,
  /\b(X[LS]|XXL|XL|LG|SM|2XL|3XL|S|M|L)\b/,
];

// Color patterns
const COLOR_MAP = {
  'أسود':'أسود','بلاك':'أسود','Black':'أسود',
  'أبيض':'أبيض','وايت':'أبيض','White':'أبيض',
  'أحمر':'أحمر','ريد':'أحمر','Red':'أحمر',
  'أزرق':'أزرق','بلو':'أزرق','Blue':'أزرق',
  'أخضر':'أخضر','جرين':'أخضر','Green':'أخضر',
  'أصفر':'أصفر','ييلو':'أصفر','Yellow':'أصفر',
  'برتقالي':'برتقالي','Orange':'برتقالي',
  'فضي':'فضي','Silver':'فضي','سيلفر':'فضي',
  'ذهبي':'ذهبي','Gold':'ذهبي','جولد':'ذهبي',
  'رمادي':'رمادي','Gray':'رمادي','Grey':'رمادي',
  'وردي':'وردي','Pink':'وردي','بيج':'بيج','Beige':'بيج',
  'بني':'بني','Brown':'بني','كحلي':'كحلي','Navy':'كحلي',
  'بنفسجي':'بنفسجي','Purple':'بنفسجي','كريمي':'كريمي','Cream':'كريمي'
};

let _autoFillTimer = null;

function smartAutoFill(nameText, prefix = 'product') {
  clearTimeout(_autoFillTimer);
  _autoFillTimer = setTimeout(() => _doSmartAutoFill(nameText, prefix), 350);
}

function _doSmartAutoFill(nameText, prefix) {
  if (!nameText || nameText.trim().length < 3) {
    const hintsBox = document.getElementById('autoFillHints');
    if (hintsBox) hintsBox.classList.add('hidden');
    return;
  }

  const hints = [];

  // --- Brand Detection ---
  const brandInput = document.getElementById(`${prefix}Brand`);
  if (brandInput && !brandInput.value.trim()) {
    const brandMatch = BRAND_REGEX.exec(nameText);
    if (brandMatch) {
      hints.push({
        label: `🏷️ البراند: ${brandMatch[1]}`,
        action: () => { brandInput.value = brandMatch[1]; brandInput.dispatchEvent(new Event('change')); }
      });
    }
  }

  // --- Size/Weight/Volume Detection ---
  const sizeInput = document.getElementById(`${prefix}Size`);
  if (sizeInput && !sizeInput.value.trim()) {
    for (const pattern of SIZE_PATTERNS) {
      const m = pattern.exec(nameText);
      if (m) {
        const sizeVal = m[0].trim();
        hints.push({
          label: `📐 الحجم/المقاس: ${sizeVal}`,
          action: () => { sizeInput.value = sizeVal; sizeInput.dispatchEvent(new Event('change')); }
        });
        break;
      }
    }
  }

  // --- Color Detection ---
  const colorInput = document.getElementById(`${prefix}Color`);
  if (colorInput && !colorInput.value.trim()) {
    for (const [key, arabicName] of Object.entries(COLOR_MAP)) {
      const colorRegex = new RegExp(`\\b${key}\\b`, 'i');
      if (colorRegex.test(nameText)) {
        hints.push({
          label: `🎨 اللون: ${arabicName}`,
          action: () => { colorInput.value = arabicName; colorInput.dispatchEvent(new Event('change')); }
        });
        break;
      }
    }
  }

  // --- Category Hint ---
  if (hints.length > 0 || categories.length > 0) {
    const catSelect = document.getElementById(`${prefix}Category`);
    if (catSelect && !catSelect.value) {
      const lowerName = nameText.toLowerCase();
      const matched = categories.find(c => lowerName.includes(c.name.toLowerCase()));
      if (matched) {
        hints.push({
          label: `📂 القسم: ${matched.name}`,
          action: () => { catSelect.value = matched.id; catSelect.dispatchEvent(new Event('change')); }
        });
      }
    }
  }

  // Show hints chips
  const hintsBox = document.getElementById('autoFillHints');
  if (!hintsBox) return;

  if (hints.length === 0) {
    hintsBox.classList.add('hidden');
    return;
  }

  hintsBox.innerHTML = `<small style="color:#64748b;font-size:0.76rem;">💡 اضغط للتعبئة التلقائية:</small> ` +
    hints.map((h, i) => `<button type="button" class="autofill-hint-chip" id="hint_chip_${i}">
      <i class="fa-solid fa-wand-magic-sparkles"></i> ${escapeHtml(h.label)}
    </button>`).join('');
  hintsBox.classList.remove('hidden');

  // Attach click handlers
  hints.forEach((h, i) => {
    const chip = document.getElementById(`hint_chip_${i}`);
    if (chip) chip.addEventListener('click', () => {
      h.action();
      chip.style.background = '#dcfce7';
      chip.style.borderColor = '#86efac';
      chip.style.color = '#15803d';
    });
  });
}


// ============================================================
// 📦 BULK IMPORT (Excel / CSV) — استيراد جماعي
// ============================================================

// Column mapping: Excel header → field name
const BULK_COLUMNS = [
  { key: 'barcode',           label: 'الباركود',              required: true  },
  { key: 'sku',               label: 'كود الصنف (SKU)',       aliases: ['كود الصنف بالمخزن (SKU)'] },
  { key: 'name',              label: 'اسم المنتج',             required: true  },
  { key: 'section',           label: 'الفئة الفرعية',         aliases: ['section_id', 'القسم الداخلي'] },
  { key: 'cost_price',        label: 'سعر التوريد',            required: false },
  { key: 'price',             label: 'سعر البيع',              required: true  },
  { key: 'compare_price',     label: 'السعر قبل الخصم',       required: false },
  { key: 'stock_quantity',    label: 'الكمية',                 required: true  },
  { key: 'unit',              label: 'وحدة القياس' },
  { key: 'pack_size',         label: 'معامل التعبئة',         aliases: ['معامل التعبئة (قطع/وحدة)'] },
  { key: 'expiry_date',       label: 'تاريخ انتهاء الصلاحية' },
  { key: 'in_stock',          label: 'متوفر بالمستودع' },
  { key: 'is_active',         label: 'نشط بالتطبيق' },
  { key: 'brand',             label: 'البراند',                required: false },
  { key: 'size',              label: 'المقاس/الحجم',           required: false },
  { key: 'serial_number',     label: 'السيريال/الموديل',      required: false },
  { key: 'color',             label: 'اللون',                  required: false },
  { key: 'warranty',          label: 'الضمان',                 required: false },
  { key: 'country_of_origin', label: 'بلد المنشأ',            required: false },
  { key: 'image_url',         label: 'رابط الصورة',           required: false },
  { key: 'description',       label: 'الوصف',                 required: false },
];

let _bulkRows = [];

function toggleBulkImportPanel() {
  const panel = document.getElementById('bulkImportPanel');
  if (panel) panel.classList.toggle('hidden');
}

function downloadBulkTemplate() {
  if (typeof XLSX === 'undefined') {
    alert('⚠️ مكتبة SheetJS غير محملة بعد. يرجى الانتظار أو التحقق من الاتصال بالإنترنت.');
    return;
  }
  const headers = BULK_COLUMNS.map(c => c.label);
  const example = {
    barcode: '6221000000001', sku: 'جبنة-001', name: 'جبنة عبور لاند 500 جرام',
    section: 'البان', cost_price: 25, price: 30, compare_price: 35,
    stock_quantity: 100, unit: 'علبة', pack_size: 1, expiry_date: '2027-12-31',
    in_stock: 'نعم', is_active: 'نعم', brand: 'عبور لاند', size: '500 جرام',
    color: 'أبيض', country_of_origin: 'مصر', description: 'جبنة بيضاء طازجة'
  };
  const exampleRow = BULK_COLUMNS.map(({ key }) => example[key] ?? '');
  const ws = XLSX.utils.aoa_to_sheet([headers, exampleRow]);
  // Set column widths
  ws['!cols'] = BULK_COLUMNS.map(() => ({ wch: 20 }));
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'سلع سوق التل');
  XLSX.writeFile(wb, 'قالب_استيراد_سلع_سوق_التل.xlsx');
}

function handleBulkImportFile(fileInput) {
  const file = fileInput.files && fileInput.files[0];
  if (!file) return;

  if (typeof XLSX === 'undefined') {
    alert('⚠️ مكتبة SheetJS غير محملة بعد. يرجى تحديث الصفحة والمحاولة مجدداً.');
    return;
  }

  const btn = document.getElementById('btnSaveBulk');
  if (btn?.disabled) return;
  const resetFileInput = () => {
    fileInput.value = '';
    fileInput.disabled = false;
    if (btn) btn.disabled = false;
  };
  _bulkRows = [];
  document.getElementById('bulkImportPreviewArea')?.classList.add('hidden');
  fileInput.disabled = true;
  if (btn) btn.disabled = true;
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = new Uint8Array(e.target.result);
      const workbook = XLSX.read(data, { type: 'array', raw: true });
      const sheetName = workbook.SheetNames[0];
      const sheet = workbook.Sheets[sheetName];
      const rows = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });

      if (!rows || rows.length < 2) {
        alert('⚠️ الملف فارغ أو لا يحتوي على بيانات. يرجى استخدام القالب النموذجي.');
        return;
      }

      parseBulkRows(rows, { sheet, date1904: workbook.Workbook?.WBProps?.date1904 === true });
    } catch (err) {
      console.error('Bulk import parse error:', err);
      alert(`❌ تعذر قراءة الملف: ${err.message}`);
    } finally {
      resetFileInput();
    }
  };
  reader.onerror = () => {
    resetFileInput();
    alert('⚠️ تعذرت قراءة الملف. حاول اختياره مرة أخرى.');
  };
  reader.readAsArrayBuffer(file);
}

function parseBulkRows(rawRows, { sheet, date1904 = false } = {}) {
  const headerRow = rawRows[0].map(normalizeSectionName);

  // Map header labels → column index
  const colIndex = {};
  for (const { key, label, aliases = [] } of BULK_COLUMNS) {
    const matchingHeaders = [label, key, ...aliases].map(normalizeSectionName);
    const index = matchingHeaders.map(h => headerRow.indexOf(h)).find(i => i >= 0);
    if (index !== undefined) colIndex[key] = index;
  }

  const origin = sheet?.['!ref'] ? XLSX.utils.decode_range(sheet['!ref']).s : { r: 0, c: 0 };
  _bulkRows = rawRows.slice(1).flatMap((row, rowIdx) => {
    if (!row.some(cell => String(cell ?? '').trim())) return [];
    const obj = {};
    for (const [key, column] of Object.entries(colIndex)) {
      const raw = row[column];
      let value = String(raw ?? '').trim();
      if (key === 'expiry_date' && value) {
        value = parseBulkExpiryDate(raw, date1904) || value;
      }
      if (sheet && typeof raw === 'number' && (key === 'barcode' || key === 'sku')) {
        const address = XLSX.utils.encode_cell({ r: origin.r + rowIdx + 1, c: origin.c + column });
        const formatted = sheet[address]?.w;
        if (/^0\d+$/.test(formatted ?? '')) value = formatted;
      }
      obj[key] = value;
    }
    obj._rowIdx = origin.r + rowIdx + 2;
    obj._errors = validateBulkRow(obj);
    return [obj];
  });

  renderBulkPreview();
}

function normalizeBulkDigits(value) {
  return String(value).replace(/[٠-٩۰-۹]/g, digit => String(digit.charCodeAt(0) & 15));
}

function parseBulkExpiryDate(value, date1904 = false) {
  const text = normalizeBulkDigits(value).trim();
  let year, month, day;
  if (typeof value === 'number' || /^\d{5}(?:\.\d+)?$/.test(text)) {
    const parsed = XLSX.SSF.parse_date_code(Number(text), { date1904 });
    if (!parsed) return null;
    ({ y: year, m: month, d: day } = parsed);
  } else {
    const iso = /^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$/.exec(text);
    const local = /^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$/.exec(text);
    if (iso) [, year, month, day] = iso;
    else if (local) [, day, month, year] = local;
    else return null;
  }
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== Number(year) || date.getUTCMonth() + 1 !== Number(month) ||
      date.getUTCDate() !== Number(day) || year < 1000 || year > 9999) return null;
  return date.toISOString().slice(0, 10);
}

const bulkYes = new Set(['1', 'true', 'yes', 'نعم', 'صح', 'صحيح', 'متوفر', 'نشط'].map(normalizeSectionName));
const bulkNo = new Set(['0', 'false', 'no', 'لا', 'خطأ', 'غير متوفر', 'غير نشط'].map(normalizeSectionName));

function parseBulkFlag(value) {
  const key = normalizeSectionName(normalizeBulkDigits(value));
  if (bulkYes.has(key)) return true;
  if (bulkNo.has(key)) return false;
  return null;
}

function bulkNumber(value) {
  const normalized = normalizeBulkDigits(value ?? '').replace(/٫/g, '.');
  return /^\d+(?:\.\d+)?$/.test(normalized) ? Number(normalized) : NaN;
}

function validateBulkRow(row) {
  const errors = [];
  if (!row.barcode) errors.push('barcode');
  if (!row.name) errors.push('name');
  const price = bulkNumber(row.price);
  const stock = bulkNumber(row.stock_quantity);
  const packSize = bulkNumber(row.pack_size);
  if (!Number.isFinite(price) || price <= 0) errors.push('price');
  if (!Number.isInteger(stock) || stock < 0 || stock > 2147483647) errors.push('stock_quantity');
  if (row.cost_price && !Number.isFinite(bulkNumber(row.cost_price))) errors.push('cost_price');
  if (row.cost_price && bulkNumber(row.cost_price) > price) errors.push('cost_price_gt_price');
  if (row.compare_price && !Number.isFinite(bulkNumber(row.compare_price))) errors.push('compare_price');
  if (row.unit && !productUnits.some(unit => normalizeSectionName(unit) === normalizeSectionName(row.unit))) errors.push('unit');
  if (row.pack_size && (!Number.isInteger(packSize) || packSize < 1 || packSize > 2147483647)) errors.push('pack_size');
  if (row.expiry_date && !parseBulkExpiryDate(row.expiry_date)) errors.push('expiry_date');
  for (const flag of ['in_stock', 'is_active']) {
    if (row[flag] && parseBulkFlag(row[flag]) === null) errors.push(flag);
  }
  return errors;
}

function renderBulkPreview() {
  const previewArea = document.getElementById('bulkImportPreviewArea');
  const thead = document.getElementById('bulkPreviewHead');
  const tbody = document.getElementById('bulkPreviewBody');
  const summary = document.getElementById('bulkImportValidationSummary');
  const rowCountEl = document.getElementById('bulkRowCount');

  if (!previewArea || !thead || !tbody || !summary) return;

  const errorRows = _bulkRows.filter(r => r._errors.length > 0);
  const validRows = _bulkRows.filter(r => r._errors.length === 0);

  // Summary
  if (errorRows.length > 0) {
    summary.className = 'bulk-validation-summary has-errors';
    summary.innerHTML = `⚠️ يوجد <strong>${errorRows.length}</strong> صف بها أخطاء (تظهر باللون الأحمر). يرجى مراجعتها. الصفوف الصحيحة: <strong>${validRows.length}</strong>`;
  } else {
    summary.className = 'bulk-validation-summary valid';
    summary.textContent = `عدد السلع الجاهزة للاستيراد ${_bulkRows.length}`;
  }

  if (rowCountEl) rowCountEl.textContent = `إجمالي الصفوف: ${_bulkRows.length} (صحيح: ${validRows.length} | أخطاء: ${errorRows.length})`;

  // Header
  thead.innerHTML = `<tr>
    <th class="row-num-cell">#</th>
    ${BULK_COLUMNS.map(c => `<th>${c.label}${c.required ? ' *' : ''}</th>`).join('')}
    <th>الحالة</th>
  </tr>`;

  // Body (show up to 200 rows for performance)
  const displayRows = _bulkRows.slice(0, 200);
  tbody.innerHTML = displayRows.map(row => {
    const hasError = row._errors.length > 0;
    const cells = BULK_COLUMNS.map(col => {
      const isErrCell = row._errors.includes(col.key)
        || (col.key === 'cost_price' && row._errors.includes('cost_price_gt_price'))
        || (col.key === 'section' && row._errors.includes('section_lookup'))
        || (col.key === 'barcode' && row._errors.some(error => error.startsWith('duplicate_')));
      return `<td class="${isErrCell ? 'cell-error' : ''}" title="${escapeHtml(row[col.key])}">${escapeHtml(row[col.key] || '—')}</td>`;
    });
    const statusCell = hasError
      ? `<td style="color:#b91c1c;font-weight:700;">❌ ${row._errors.map(e => {
          const labels = {
            cost_price_gt_price: 'سعر التوريد أعلى من سعر البيع',
            section: 'تعذّر مطابقة الفئة الفرعية أو إنشاؤها',
            section_lookup: 'تعذّر تحميل أقسام المتجر',
            duplicate_barcode: 'الباركود مكرّر في الملف',
            duplicate_store_barcode: 'الباركود مسجّل لمتجر آخر',
            save_error: 'تعذّر حفظ الصف'
          };
          return labels[e] || BULK_COLUMNS.find(col => col.key === e)?.label || e;
        }).join(', ')}</td>`
      : `<td style="color:#15803d;font-weight:700;">✅ جاهز</td>`;
    return `<tr class="${hasError ? 'row-error' : ''}">
      <td class="row-num-cell">${row._rowIdx}</td>
      ${cells.join('')}
      ${statusCell}
    </tr>`;
  }).join('');

  if (_bulkRows.length > 200) {
    tbody.innerHTML += `<tr><td colspan="${BULK_COLUMNS.length + 2}" style="text-align:center;color:#64748b;padding:12px;">و ${_bulkRows.length - 200} صف إضافي خارج المعاينة</td></tr>`;
  }

  previewArea.classList.remove('hidden');
  document.getElementById('bulkProgressArea')?.classList.add('hidden');
}

async function resolveBulkProductSection(row, storeId, sections) {
  const detected = row.section ? null : detectProductSubCategory(row.name, sections);
  if (detected?.id) return detected.id;

  const name = row.section || detected?.name;
  if (!name) return null;
  const normalized = normalizeSectionName(name);
  const match = sections.find(section => section.id === normalized || normalizeSectionName(section.name) === normalized);
  if (match) return match.id;
  if (/^[\da-f]{8}-(?:[\da-f]{4}-){3}[\da-f]{12}$/.test(normalized)) {
    throw new Error("معرّف الفئة الفرعية غير مسجّل لهذا المتجر.");
  }

  const { data, error } = await supabaseClient.rpc('resolve_bulk_store_section', {
    p_store_id: storeId,
    p_name: name
  });
  if (error || !data) throw error || new Error('Store section ID was not returned.');
  sections.push(withSectionPhrases({ id: data, name }));
  return data;
}

async function saveBulkProducts() {
  const btn = document.getElementById('btnSaveBulk');
  if (btn?.disabled) return;
  const categorySelect = document.getElementById('bulkImportCategory');
  const supplierSelect = document.getElementById('bulkImportSupplier');
  const selectedCategoryId = categorySelect?.value;
  const selectedSupplierId = supplierSelect?.value;
  if (!selectedCategoryId) {
    alert('⚠️ اختر القسم الرئيسي لجميع سلع الملف.');
    categorySelect?.focus();
    return;
  }
  if (!selectedSupplierId) {
    alert('⚠️ اختر المورّد الشريك / التاجر لجميع سلع الملف.');
    supplierSelect?.focus();
    return;
  }

  const rows = _bulkRows;
  for (const row of rows) row._errors = validateBulkRow(row);
  const validRows = rows.filter(row => row._errors.length === 0);
  if (validRows.length === 0) {
    renderBulkPreview();
    alert('⚠️ لا توجد صفوف صحيحة للحفظ. يرجى مراجعة الأخطاء أولاً.');
    return;
  }

  const supplierName = supplierSelect.selectedOptions[0].textContent;
  if (!confirm(`هل تريد استيراد ${validRows.length} سلعة إلى «${supplierName}»؟`)) return;

  const fileInput = document.getElementById('bulkImportFile');
  categorySelect.disabled = true;
  supplierSelect.disabled = true;
  if (fileInput) fileInput.disabled = true;
  if (btn) {
    btn.disabled = true;
    btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> جاري تجهيز الاستيراد...';
  }

  const progressArea = document.getElementById('bulkProgressArea');
  const progressBar = document.getElementById('bulkProgressBar');
  const progressText = document.getElementById('bulkProgressText');
  const progressCount = document.getElementById('bulkProgressCount');
  const savedRows = new Set();
  const batchSize = 20;
  try {
    if (progressArea) progressArea.classList.remove('hidden');
    if (progressBar) progressBar.style.width = '0%';
    if (progressCount) progressCount.textContent = `0 / ${validRows.length}`;
    if (progressText) progressText.textContent = 'جارٍ تحميل الفئات الفرعية للمتجر...';
    const barcodeCounts = new Map();
    for (const row of validRows) barcodeCounts.set(row.barcode, (barcodeCounts.get(row.barcode) || 0) + 1);
    for (const row of validRows) {
      if (barcodeCounts.get(row.barcode) > 1) row._errors.push('duplicate_barcode');
    }
    const readyRows = validRows.filter(row => row._errors.length === 0);
    let sections = [];
    if (readyRows.length) {
      try {
        sections = (await fetchStoreSections(selectedSupplierId)).map(withSectionPhrases);
      } catch (error) {
        for (const row of readyRows) row._errors.push('section_lookup');
        throw error;
      }
    }

    for (let i = 0; i < readyRows.length; i += batchSize) {
      const batch = readyRows.slice(i, i + batchSize);
      const { data: existingRows, error: lookupError } = await supabaseClient.from('products')
        .select('id, store_id, barcode').in('barcode', batch.map(row => row.barcode));
      if (lookupError) throw lookupError;

      const existingByBarcode = new Map(existingRows.map(product => [product.barcode, product]));
      for (const row of batch) {
        try {
          const existing = existingByBarcode.get(row.barcode);
          if (existing && existing.store_id !== selectedSupplierId) {
            row._errors.push('duplicate_store_barcode');
            continue;
          }
          const existingId = existing?.id;
          let sectionId;
          try {
            sectionId = await resolveBulkProductSection(row, selectedSupplierId, sections);
          } catch (error) {
            console.error(`Bulk section failed for row ${row._rowIdx}:`, error);
            row._errors.push('section');
            continue;
          }
          const isLocal = row.barcode.startsWith('200');
          const customFields = {
            brand: row.brand,
            size: row.size,
            serial_number: row.serial_number,
            color: row.color,
            warranty: row.warranty,
            country_of_origin: row.country_of_origin,
            [isLocal ? 'local_barcode' : 'international_barcode']: row.barcode
          };
          for (const key of Object.keys(customFields)) {
            if (!customFields[key]) delete customFields[key];
          }

          let imageUrl = /^https?:\/\//i.test(row.image_url || '') ? row.image_url : null;
          if (!imageUrl && !isLocalBarcode(row.barcode)) {
            if (progressText) progressText.textContent = `جاري البحث عن صورة للصف ${row._rowIdx}...`;
            imageUrl = await fetchRealProductImageByBarcode(row.barcode);
          }

          const stock = bulkNumber(row.stock_quantity);
          const payload = {
            barcode: row.barcode,
            name: row.name,
            category_id: selectedCategoryId,
            store_id: selectedSupplierId,
            cost_price: row.cost_price ? bulkNumber(row.cost_price) : null,
            price: bulkNumber(row.price),
            compare_price: row.compare_price ? bulkNumber(row.compare_price) || null : null,
            stock_quantity: stock,
            in_stock: parseBulkFlag(row.in_stock) ?? stock > 0,
            image_url: imageUrl,
            image_urls: imageUrl ? [imageUrl] : [],
            description: row.description || null,
            custom_fields: customFields,
            variant_groups: null,
            variants: null
          };
          if (!existingId || Object.hasOwn(row, 'is_active')) payload.is_active = parseBulkFlag(row.is_active) ?? true;
          if (!existingId || sectionId) payload.section_id = sectionId;
          if (!existingId || Object.hasOwn(row, 'sku')) payload.sku = row.sku || null;
          if (!existingId || Object.hasOwn(row, 'unit')) {
            payload.unit = productUnits.find(unit => normalizeSectionName(unit) === normalizeSectionName(row.unit)) || 'قطعة';
          }
          if (!existingId || Object.hasOwn(row, 'pack_size')) payload.pack_size = bulkNumber(row.pack_size) || 1;
          if (!existingId || Object.hasOwn(row, 'expiry_date')) payload.expiry_date = row.expiry_date || null;

          const query = supabaseClient.from('products');
          const { data, error } = await (existingId
            ? query.update(payload).eq('id', existingId).eq('store_id', selectedSupplierId)
            : query.insert(payload)).select('id').single();
          if (error || !data) throw error || new Error('The imported product was not returned.');
          savedRows.add(row);
        } catch (error) {
          console.error(`Bulk import failed for row ${row._rowIdx}:`, error);
          row._errors.push(error.code === '23505' ? 'duplicate_store_barcode' : 'save_error');
        }
      }
      const processed = i + batch.length;
      const percent = Math.round(processed / readyRows.length * 100);
      if (progressBar) progressBar.style.width = `${percent}%`;
      if (progressText) progressText.textContent = `تمت معالجة ${percent}% من الصفوف القابلة للحفظ`;
      if (progressCount) progressCount.textContent = `${processed} / ${readyRows.length}`;
    }
    if (savedRows.size) await loadInventory();
  } catch (error) {
    console.error('Bulk import failed:', error);
    for (const row of validRows) {
      if (!savedRows.has(row) && row._errors.length === 0) row._errors.push('save_error');
    }
  } finally {
    categorySelect.disabled = false;
    supplierSelect.disabled = false;
    if (fileInput) fileInput.disabled = false;
    if (btn) {
      btn.disabled = false;
      btn.innerHTML = '<i class="fa-solid fa-floppy-disk"></i> <span>حفظ جميع السلع بالمستودع دفعة واحدة</span>';
    }
  }

  _bulkRows = rows.filter(row => !savedRows.has(row));
  if (_bulkRows.length) {
    renderBulkPreview();
    alert(`تم حفظ ${savedRows.size} سلعة. راجع أسباب تعذر حفظ ${_bulkRows.length} صف في المعاينة.`);
  } else {
    document.getElementById('bulkImportPreviewArea')?.classList.add('hidden');
    document.getElementById('bulkImportPanel')?.classList.add('hidden');
    alert(`✅ تم حفظ ${savedRows.size} سلعة في المستودع بنجاح!`);
  }
}


// ============================================================
// 🖼️ REAL PRODUCT IMAGE LOOKUP, MISSING IMAGES & QUICK UPLOAD
// ============================================================

/**
 * Query Open Food Facts v2 (and Open Beauty Facts fallback) for a real product.image_front_url.
 * If not found by barcode and productName is provided, falls back to Open Food Facts text search.
 */
async function fetchRealProductImageByBarcode(barcode, productName = '') {
  const clean = cleanBarcode(barcode);

  const fetchWithTimeout = (url, ms = 3500) => {
    const controller = new AbortController();
    const t = setTimeout(() => controller.abort(), ms);
    return fetch(url, { signal: controller.signal }).finally(() => clearTimeout(t));
  };

  if (clean && !isLocalBarcode(clean)) {
    const endpoints = [
      `https://world.openfoodfacts.org/api/v2/product/${encodeURIComponent(clean)}.json`,
      `https://world.openbeautyfacts.org/api/v2/product/${encodeURIComponent(clean)}.json`
    ];

    for (const url of endpoints) {
      try {
        const res = await fetchWithTimeout(url, 3500);
        if (res.ok) {
          const data = await res.json();
          if (data && data.status === 1 && data.product && data.product.image_front_url) {
            const imgUrl = String(data.product.image_front_url).trim();
            if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
              return imgUrl;
            }
          }
        }
      } catch (e) {
        // Ignore timeout/network error and try next endpoint
      }
    }
  }

  // Fallback: Search by product name in Open Food Facts
  const cleanName = String(productName || '').trim();
  if (cleanName.length >= 3) {
    try {
      const searchUrl = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(cleanName)}&search_simple=1&action=process&json=1&page_size=1`;
      const res = await fetchWithTimeout(searchUrl, 4000);
      if (res.ok) {
        const data = await res.json();
        if (data && Array.isArray(data.products) && data.products.length > 0 && data.products[0].image_front_url) {
          const imgUrl = String(data.products[0].image_front_url).trim();
          if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
            return imgUrl;
          }
        }
      }
    } catch (e) {
      // Ignore timeout/network error
    }
  }

  return null;
}

/**
 * Scan products missing image_url, fetch real image_front_url
 * by barcode (or product name fallback) from Open Food Facts, and update Supabase.
 */
async function fetchMissingProductImages() {
  const candidates = productsList.filter(p => {
    const hasImg = p.image_url && String(p.image_url).trim() !== '';
    const code = cleanBarcode(p.barcode || p.custom_fields?.international_barcode || '');
    const hasName = p.name && String(p.name).trim().length >= 3;
    return !hasImg && ((code && !isLocalBarcode(code)) || hasName);
  });

  if (candidates.length === 0) {
    alert('✅ جميع المنتجات لديها صور بالفعل أو لا توجد بيانات كافية للبحث!');
    return;
  }

  if (!confirm(`تم العثور على ${candidates.length} منتج بدون صورة.\nهل تريد البحث عن صورها (بالباركود أو باسم المنتج) وتحديثها الآن؟`)) {
    return;
  }

  const btn = document.getElementById('btnFetchMissingImages');
  const progressArea = document.getElementById('missingImagesProgressArea');
  const progressBar = document.getElementById('missingImagesProgressBar');
  const progressText = document.getElementById('missingImagesProgressText');
  const progressCount = document.getElementById('missingImagesProgressCount');

  if (btn) {
    btn.disabled = true;
    btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> <span>جاري جلب الصور...</span>';
  }
  if (progressArea) progressArea.classList.remove('hidden');

  let updatedCount = 0;
  let processed = 0;

  for (const p of candidates) {
    const code = cleanBarcode(p.barcode || p.custom_fields?.international_barcode || '');
    const foundUrl = await fetchRealProductImageByBarcode(code, p.name || '');

    if (foundUrl) {
      const { error: updErr } = await supabaseClient
        .from('products')
        .update({
          image_url: foundUrl,
          image_urls: [foundUrl]
        })
        .eq('id', p.id);

      if (!updErr) {
        p.image_url = foundUrl;
        p.image_urls = [foundUrl];
        updatedCount++;
      } else {
        console.error('Error updating missing image for product:', p.id, updErr.message);
      }
    }

    processed++;
    const pct = Math.round((processed / candidates.length) * 100);
    if (progressBar) progressBar.style.width = `${pct}%`;
    if (progressText) progressText.textContent = `جاري الفحص... (تم تحديث ${updatedCount} صورة)`;
    if (progressCount) progressCount.textContent = `${processed} / ${candidates.length}`;
  }

  if (typeof applyInventoryFilter === 'function') {
    applyInventoryFilter();
  } else {
    renderInventoryTable(productsList);
  }

  if (btn) {
    btn.disabled = false;
    btn.innerHTML = '<i class="fa-solid fa-images"></i> <span>جلب الصور المفقودة تلقائياً</span>';
  }

  setTimeout(() => {
    if (progressArea) progressArea.classList.add('hidden');
  }, 3000);

  alert(`✅ اكتمل الفحص لـ ${candidates.length} منتج!\nتم العثور على وتحديث ${updatedCount} صورة بنجاح.`);
}

// ============================================================
// ⚡ QUICK IMAGE UPLOAD / URL MODAL FOR INVENTORY TABLE
// ============================================================

function openQuickImageModal(productId) {
  const p = productsList.find(item => item.id === productId);
  if (!p) return;

  const modal = document.getElementById('quickImageModal');
  const idInput = document.getElementById('quickImageProductId');
  const nameEl = document.getElementById('quickImageProductName');
  const previewEl = document.getElementById('quickImagePreview');
  const urlInput = document.getElementById('quickImageUrlInput');
  const statusEl = document.getElementById('quickImageStatus');

  if (!modal) return;
  if (idInput) idInput.value = p.id;
  if (nameEl) nameEl.textContent = p.name || '';
  if (urlInput) urlInput.value = p.image_url || '';
  if (statusEl) statusEl.classList.add('hidden');

  if (previewEl) {
    if (p.image_url) {
      previewEl.src = p.image_url;
      previewEl.classList.remove('hidden');
    } else {
      previewEl.classList.add('hidden');
    }
  }

  modal.classList.add('active');
}

function closeQuickImageModal() {
  const modal = document.getElementById('quickImageModal');
  if (modal) modal.classList.remove('active');
}

async function handleQuickImageFileUpload(fileInput) {
  const file = fileInput.files && fileInput.files[0];
  if (!file) return;
  await _uploadQuickImageFileOrBlob(file);
  fileInput.value = '';
}

async function _uploadQuickImageFileOrBlob(fileOrBlob) {
  const productId = document.getElementById('quickImageProductId')?.value;
  if (!fileOrBlob || !productId) return;

  const p = productsList.find(item => item.id === productId);
  const statusEl = document.getElementById('quickImageStatus');
  const previewEl = document.getElementById('quickImagePreview');
  const btnUpload = document.getElementById('btnQuickUploadFromDevice');

  const showQuickStatus = (msg, type = 'loading') => {
    if (!statusEl) return;
    statusEl.innerHTML = msg;
    statusEl.className = `image-upload-status ${type}`;
    statusEl.classList.remove('hidden');
  };

  if (btnUpload) btnUpload.disabled = true;
  showQuickStatus('<i class="fa-solid fa-spinner fa-spin"></i> جاري ضغط ورفع الصورة إلى Supabase Storage...', 'loading');

  try {
    const compressedDataUrl = await compressImageFile(fileOrBlob, 1000, 0.85, 'image/webp');
    const compressedBlob = dataURLtoBlob(compressedDataUrl);
    const actualMime = compressedBlob.type || 'image/webp';
    const ext = actualMime.includes('webp') ? 'webp' : 'jpg';

    const authUser = (await supabaseClient.auth.getUser())?.data?.user;
    const userId = currentUser?.id || authUser?.id || 'admin';
    const storeId = p?.store_id || suppliers[0]?.id || 'default';

    const filePath = `${userId}/products/${storeId}/${productId}_${Date.now()}.${ext}`;

    const { error: uploadErr } = await supabaseClient.storage
      .from('products')
      .upload(filePath, compressedBlob, { contentType: actualMime, upsert: true });

    if (uploadErr) {
      throw new Error(uploadErr.message);
    }

    const { data: pubData } = supabaseClient.storage.from('products').getPublicUrl(filePath);
    const publicUrl = pubData?.publicUrl;
    if (!publicUrl) throw new Error('لم يتم استرجاع رابط الصورة العام');

    await _commitQuickProductImage(productId, publicUrl, previewEl, showQuickStatus);
  } catch (err) {
    console.error('Quick image upload error:', err);
    showQuickStatus(`❌ تعذر رفع الصورة: ${err.message}`, 'error');
  } finally {
    if (btnUpload) btnUpload.disabled = false;
  }
}

// Listen for Ctrl+V / Paste of an image while Quick Image Modal is open
document.addEventListener('paste', async (e) => {
  const modal = document.getElementById('quickImageModal');
  if (!modal || !modal.classList.contains('active')) return;

  const items = e.clipboardData?.items;
  if (!items) return;

  for (const item of items) {
    if (item.type && item.type.startsWith('image/')) {
      e.preventDefault();
      const blob = item.getAsFile();
      if (blob) {
        await _uploadQuickImageFileOrBlob(blob);
      }
      break;
    }
  }
});

async function saveQuickImageUrl() {
  const productId = document.getElementById('quickImageProductId')?.value;
  const rawUrl = (document.getElementById('quickImageUrlInput')?.value || '').trim();
  const statusEl = document.getElementById('quickImageStatus');
  const previewEl = document.getElementById('quickImagePreview');
  const btnSave = document.getElementById('btnQuickSaveUrl');

  const showQuickStatus = (msg, type = 'loading') => {
    if (!statusEl) return;
    statusEl.innerHTML = msg;
    statusEl.className = `image-upload-status ${type}`;
    statusEl.classList.remove('hidden');
  };

  if (!productId) return;
  if (!rawUrl || !(rawUrl.startsWith('http://') || rawUrl.startsWith('https://'))) {
    showQuickStatus('⚠️ يرجى إدخال رابط صورة صالح يبدأ بـ http:// أو https://', 'error');
    return;
  }

  if (btnSave) btnSave.disabled = true;
  showQuickStatus('<i class="fa-solid fa-spinner fa-spin"></i> جاري تحديث رابط الصورة...', 'loading');

  try {
    await _commitQuickProductImage(productId, rawUrl, previewEl, showQuickStatus);
  } catch (err) {
    console.error('Quick URL save error:', err);
    showQuickStatus(`❌ تعذر حفظ الرابط: ${err.message}`, 'error');
  } finally {
    if (btnSave) btnSave.disabled = false;
  }
}

async function _commitQuickProductImage(productId, finalUrl, previewEl, showQuickStatus) {
  const p = productsList.find(item => item.id === productId);
  const existingGallery = Array.isArray(p?.image_urls) ? p.image_urls.filter(u => u && u !== p.image_url) : [];
  const updatedUrls = Array.from(new Set([finalUrl, ...existingGallery]));

  const { error: dbErr } = await supabaseClient
    .from('products')
    .update({
      image_url: finalUrl,
      image_urls: updatedUrls
    })
    .eq('id', productId);

  if (dbErr) throw new Error(dbErr.message);

  if (p) {
    p.image_url = finalUrl;
    p.image_urls = updatedUrls;
  }

  if (previewEl) {
    previewEl.src = finalUrl;
    previewEl.classList.remove('hidden');
  }

  if (typeof applyInventoryFilter === 'function') {
    applyInventoryFilter();
  } else {
    renderInventoryTable(productsList);
  }

  showQuickStatus('<i class="fa-solid fa-circle-check"></i> تم تحديث صورة المنتج بنجاح!', 'success');
  setTimeout(() => closeQuickImageModal(), 900);
}
