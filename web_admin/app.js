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

    applyUserUI(currentUser);
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
}

function showLoginUI() {
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

function applyUserUI(user) {
  const nameEl = document.getElementById("navUserName");
  const roleEl = document.getElementById("navUserRole");
  if (nameEl) nameEl.textContent = user.full_name || user.email || 'المدير العام';
  if (roleEl) {
    roleEl.textContent = 'مدير عام (Admin)';
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

// ==========================================
// 🏷️ UNIFIED BARCODE MANAGEMENT
// ==========================================
function generateLocalBarcode(targetInputId = "productBarcode") {
  const input = document.getElementById(targetInputId);
  if (!input) return;

  // توليد باركود محلي قياسي مكون من 13 رقم يبدأ بـ 200
  let code = "200" + Math.floor(100000000 + Math.random() * 900000000).toString();
  let sum = 0;
  for (let i = 0; i < 12; i++) {
    sum += parseInt(code[i], 10) * (i % 2 === 0 ? 1 : 3);
  }
  const checkDigit = (10 - (sum % 10)) % 10;
  const generated = code + checkDigit;

  input.value = generated;
  input.focus();

  if (typeof checkBarcodeForEdit === "function") {
    checkBarcodeForEdit(generated);
  }
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

    if (categorySelect && filterCategory) {
      const optionsHtml = categories.map(cat => `<option value="${cat.id}">${cat.name}</option>`).join("");
      categorySelect.innerHTML = '<option value="">اختر القسم...</option>' + optionsHtml;
      filterCategory.innerHTML = '<option value="">جميع الأقسام</option>' + optionsHtml;
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

    if (supplierSelect && filterSupplier) {
      const selectOptions = suppliers.map(sup => {
        const catText = sup.category ? ` (${sup.category})` : '';
        return `<option value="${sup.id}">${sup.name || 'مورّد'}${catText}</option>`;
      }).join("");

      const filterOptions = suppliers.map(sup => `<option value="${sup.id}">${sup.name || 'مورّد'}</option>`).join("");

      supplierSelect.innerHTML = '<option value="">اختر المورّد/المتجر...</option>' + selectOptions;
      filterSupplier.innerHTML = '<option value="">جميع الموردين/المتاجر</option>' + filterOptions;
    }
  } catch (err) {
    console.error("خطأ في جلب الموردين:", err);
  }
}

// Load Inventory / Products from Supabase
async function loadInventory() {
  try {
    let { data, error } = await supabaseClient
      .from("products")
      .select("*, categories(name), stores(name)")
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

// Render Inventory Table
function renderInventoryTable(items) {
  const tbody = document.getElementById("inventoryTbody");
  if (!tbody) return;

  if (!items || items.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="empty-table-cell">لا توجد سلع مسجلة بالمستودع حالياً</td></tr>`;
    return;
  }

  tbody.innerHTML = items.map(p => {
    const qty = p.stock_quantity ?? 0;
    const badgeClass = qty > 10 ? "badge-success" : qty > 0 ? "badge-warning" : "badge-danger";
    const qtyText = qty > 0 ? `${qty} قطعة` : "نفذت الكمية";
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
              ${mainBarcode ? `<div class="${isLocal ? 'badge-local-barcode' : 'meta-tag badge-global-barcode'}" title="الباركود"><i class="fa-solid fa-barcode"></i> <strong>${mainBarcode}</strong> <span class="barcode-type-tag">${isLocal ? 'محلي' : 'دولي/مصنع'}</span></div>` : '<span class="text-muted">بدون باركود</span>'}
            `;
          })()}
        </td>
        <td>
          <div class="product-item-cell">
            ${p.image_url ? `<img src="${p.image_url}" class="product-thumb" alt="${p.name || ''}" onclick="openFullImage('${p.image_url}')" title="انقر لعرض الصورة بحجمها الكامل" style="cursor: pointer;">` : ''}
            <div>
              <strong>${p.name || ''}</strong>
              <div class="product-desc-text">${p.description || ''}</div>
              <div class="meta-tags-container">
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
        <td>${p.categories?.name || 'غير محدد'}</td>
        <td>${supplierName}</td>
        <td><strong class="text-danger">${p.cost_price ? p.cost_price + ' ج.م' : '-'}</strong></td>
        <td><strong class="text-primary">${p.price ? p.price + ' ج.م' : '-'}</strong></td>
        <td><span class="badge ${badgeClass}">${qtyText}</span></td>
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
  document.getElementById("modalEditInStock").checked = p.in_stock !== false;
  document.getElementById("modalEditIsActive").checked = p.is_active !== false;
  document.getElementById("modalEditImageUrl").value = p.image_url || "";
  document.getElementById("modalEditDescription").value = p.description || "";

  document.getElementById("modalEditBrand").value = cf.brand || p.brand || "";
  document.getElementById("modalEditSize").value = cf.size || cf.volume || cf.weight || p.size || "";
  document.getElementById("modalEditSerialNumber").value = cf.serial_number || "";
  document.getElementById("modalEditColor").value = cf.color || "";
  document.getElementById("modalEditWarranty").value = cf.warranty || "";
  document.getElementById("modalEditOrigin").value = cf.country_of_origin || "";

  updateImagePreview("modalEditImageUrl", "modalEditImagePreview", "modalEditImagePlaceholder");

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
    let targetStoreId = supplierId || null;
    if (!targetStoreId && suppliers.length > 0) {
      targetStoreId = suppliers[0].id;
    }

    const existingProd = productsList.find(p => p.id === productId);
    const existingCustomFields = (existingProd && existingProd.custom_fields && typeof existingProd.custom_fields === 'object')
      ? { ...existingProd.custom_fields }
      : {};

    const isLocal = barcode.startsWith("200");
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

    const updatePayload = {
      barcode: barcode,
      name: name,
      category_id: categoryId || null,
      store_id: targetStoreId,
      cost_price: isNaN(costPrice) ? null : costPrice,
      price: price,
      compare_price: isNaN(comparePrice) ? null : comparePrice,
      stock_quantity: stockQuantity,
      in_stock: inStock,
      is_active: isActive,
      image_url: imageUrl || null,
      image_urls: (imageUrl && !imageUrl.startsWith('data:')) ? [imageUrl] : null,
      description: description || null,
      custom_fields: updatedCustomFields
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
  if (supplierSelect && (prod.store_id || prod.merchant_id)) supplierSelect.value = prod.store_id || prod.merchant_id;
  if (costPriceInput) costPriceInput.value = prod.cost_price ?? "";
  if (priceInput) priceInput.value = prod.price ?? "";
  if (comparePriceInput) comparePriceInput.value = prod.compare_price ?? "";
  if (stockInput) stockInput.value = prod.stock_quantity ?? 0;
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

  updateImagePreview(`${prefix}ImageUrl`, `${prefix}ImagePreview`, `${prefix}ImagePlaceholder`);

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
    if (editingId) {
      const existingProd = productsList.find(p => p.id === editingId);
      if (existingProd && existingProd.custom_fields && typeof existingProd.custom_fields === 'object') {
        existingCustomFields = { ...existingProd.custom_fields };
      }
    }

    const isLocal = barcode.startsWith("200");
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

    const productPayload = {
      barcode: barcode,
      name: name,
      category_id: categoryId || null,
      store_id: targetStoreId,
      cost_price: isNaN(costPrice) ? null : costPrice,
      price: price,
      compare_price: isNaN(comparePrice) ? null : comparePrice,
      stock_quantity: stockQuantity,
      in_stock: inStock,
      is_active: isActive,
      description: description || null,
      image_url: imageUrl || null,
      image_urls: (imageUrl && !imageUrl.startsWith('data:')) ? [imageUrl] : null,
      custom_fields: updatedCustomFields
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

// Barcode Scanner Listener for POS
function initPosScanner() {
  const scannerInput = document.getElementById("posBarcodeScanner");
  if (!scannerInput) return;

  // High speed barcode scanner listener (triggers on Enter)
  scannerInput.addEventListener("keypress", async (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      const code = scannerInput.value.trim();
      if (code) {
        await scanAndAddToCart(code);
        scannerInput.value = "";
      }
    }
  });
}

// Add scanned product to POS receipt
async function scanAndAddToCart(barcodeOrQuery) {
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

  if (!product) {
    showPosBarcodeUnregisteredDialog(code);
    return;
  }

  const currentInCart = cartItems.find(i => i.product.id === product.id);
  const qtyInCart = currentInCart ? currentInCart.quantity : 0;

  if (product.stock_quantity !== null && (qtyInCart + 1) > product.stock_quantity) {
    alert(`⚠️ لا توجد كمية كافية بالمخزن! الكمية المتاحة: ${product.stock_quantity}`);
    return;
  }

  if (currentInCart) {
    currentInCart.quantity += 1;
  } else {
    cartItems.push({ product: product, quantity: 1 });
  }

  renderPosReceipt();
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
          <strong style="font-family: monospace; font-size: 1.1rem; color: var(--primary);">${barcode}</strong>
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
            <button type="button" class="btn btn-success" style="width: 100%; margin-top: 8px;" onclick="posQuickLinkAndAdd('${barcode}')">
              <i class="fa-solid fa-check"></i> ربط الباركود وحفظه وإضافة السلعة للرسيد الآن
            </button>
          </div>
        ` : ''}

        <div style="text-align: center; border-top: 1px dashed #cbd5e1; padding-top: 1rem; display: flex; justify-content: center; gap: 8px;">
          <button type="button" class="btn btn-primary" onclick="posGoToAddProduct('${barcode}')">
            <i class="fa-solid fa-plus"></i> إضافة سلعة جديدة بهذا الباركود بالمستودع
          </button>
          <button type="button" class="btn btn-secondary" onclick="closePosUnregisteredModal()">
            إلغاء
          </button>
        </div>
      </div>
    </div>
  `;
}

function closePosUnregisteredModal() {
  const modal = document.getElementById("posUnregisteredModal");
  if (modal) modal.classList.remove("active");
}

async function posQuickLinkAndAdd(barcode) {
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
    cartItems.push({ product: prod, quantity: 1 });
    renderPosReceipt();
    alert(`✅ تم ربط الباركود بالسلعة "${prod.name}" بنجاح وإضافتها للرسيد!`);
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
  if (cartItems.length === 0) {
    container.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 2rem 0;">الرسيد فارغ. قم بمسح باركود السلعة لإضافتها للكاشير.</div>`;
    const totalEl = document.getElementById("posTotalAmount");
    if (totalEl) totalEl.innerText = "0.00 ج.م";
    return;
  }

  let total = 0;
  container.innerHTML = cartItems.map((item, index) => {
    const itemTotal = item.product.price * item.quantity;
    total += itemTotal;

    return `
      <div class="receipt-item">
        <div>
          <strong>${item.product.name}</strong>
          <div style="font-size: 0.8rem; color: var(--text-muted);">${item.product.price} ج.م × ${item.quantity}</div>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <button class="btn btn-secondary" style="padding: 2px 8px;" onclick="updateCartQty(${index}, -1)">-</button>
          <span>${item.quantity}</span>
          <button class="btn btn-secondary" style="padding: 2px 8px;" onclick="updateCartQty(${index}, 1)">+</button>
          <strong style="margin-right: 8px; color: var(--primary);">${itemTotal.toFixed(2)} ج.م</strong>
        </div>
      </div>
    `;
  }).join("");

  const totalEl = document.getElementById("posTotalAmount");
  if (totalEl) totalEl.innerText = `${total.toFixed(2)} ج.م`;
}

function updateCartQty(index, change) {
  if (index < 0 || index >= cartItems.length) return;
  cartItems[index].quantity += change;
  if (cartItems[index].quantity <= 0) {
    cartItems.splice(index, 1);
  }
  renderPosReceipt();
}

// Finalize POS Sale & Deduct Stock in Supabase
async function checkoutPosSale() {
  if (cartItems.length === 0) {
    alert("⚠️ سلة الكاشير فارغة!");
    return;
  }

  const btnCheckout = document.getElementById("btnCheckoutPos");
  if (btnCheckout) {
    btnCheckout.disabled = true;
    btnCheckout.innerText = "⏳ جاري إتمام البيع وتحديث المخزون...";
  }

  try {
    for (const item of cartItems) {
      const p = item.product;
      const newStock = Math.max(0, (p.stock_quantity ?? 0) - item.quantity);

      await supabaseClient
        .from("products")
        .update({
          stock_quantity: newStock,
          in_stock: newStock > 0
        })
        .eq("id", p.id)
        .select();
    }

    alert("✅ تم إتمام الفاتورة وتحديث كميات المستودع بنجاح!");
    cartItems = [];
    renderPosReceipt();
    await loadInventory();
  } catch (err) {
    alert("❌ حدث خطأ أثناء إتمام العملية: " + err.message);
  } finally {
    if (btnCheckout) {
      btnCheckout.disabled = false;
      btnCheckout.innerText = "💵 إتمام العملية وطباعة الفاتورة";
    }
  }
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
    if (statusEl) statusEl.classList.add("hidden");
  };

  showStatus(`جاري فحص الباركود (${barcode})...`, "loading");

  try {
    // 1. أولاً: فحص قاعدة بيانات المستودع (الكاش المحلي + Supabase)
    const localProd = await findProductByBarcode(barcode);

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

      const [offRes, egRes] = await Promise.allSettled([
        fetchWithTimeout(`https://world.openfoodfacts.org/api/v0/product/${encodeURIComponent(barcode)}.json`),
        fetchWithTimeout(`https://eg.openfoodfacts.org/api/v0/product/${encodeURIComponent(barcode)}.json`)
      ]);

      if (offRes.status === "fulfilled" && offRes.value.ok) {
        const data = await offRes.value.json();
        if (data && (data.status === 1 || data.status_verbose === "product found") && data.product) {
          result = parseGlobalProductData(data.product);
        }
      }

      if ((!result || !result.name) && egRes.status === "fulfilled" && egRes.value.ok) {
        const data = await egRes.value.json();
        if (data && (data.status === 1 || data.status_verbose === "product found") && data.product) {
          result = parseGlobalProductData(data.product);
        }
      }
    } catch (e) {
      console.warn("Online barcode lookup error:", e);
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

      if (result.categoryHint && categories.length > 0) {
        const hint = (result.categoryHint + " " + result.name).toLowerCase();
        const matchedCategory = categories.find(cat => hint.includes(cat.name.toLowerCase()));
        const catSelect = document.getElementById(`${prefix}Category`);
        if (matchedCategory && catSelect) catSelect.value = matchedCategory.id;
      }

      showStatus(`✅ تم جلب بيانات السلعة من السجل الدولي: "<strong>${result.name}</strong>" بنجاح وتعبئة الحقول المتاحة!`, "success");
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
  let skuCode = "P" + (product.id ? product.id.replace(/-/g, "").substring(0, 4).toUpperCase() : "001");
  if (product.sku) {
    skuCode = product.sku.replace(/[^a-zA-Z0-9]/g, "").toUpperCase().substring(0, 6);
  }

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

    // 2. Try uploading to Supabase Storage bucket 'products'
    let finalImageUrl = compressedDataUrl;
    let uploadedToStorage = false;

    try {
      if (supabaseClient && supabaseClient.storage) {
        showUploadStatus('<i class="fa-solid fa-spinner fa-spin"></i> جاري رفع الصورة إلى سحابة التخزين...', 'loading');
        const fileExt = (file.name.split('.').pop() || 'jpg').toLowerCase();
        const cleanFileName = `prod_${Date.now()}_${Math.random().toString(36).substring(2, 7)}.${fileExt}`;
        const userFolder = currentUser?.id || 'admin';
        const filePath = `${userFolder}/${cleanFileName}`;

        const { data: uploadData, error: uploadErr } = await supabaseClient.storage
          .from("products")
          .upload(filePath, file, {
            contentType: file.type || 'image/jpeg',
            upsert: true
          });

        if (!uploadErr && uploadData) {
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
    }

    // 3. Set URL in input
    const urlInput = document.getElementById(urlInputId);
    if (urlInput) {
      urlInput.value = finalImageUrl;
    }

    // 4. Update preview box
    updateImagePreview(urlInputId, previewImgId, placeholderId);

    showUploadStatus(`
      <i class="fa-solid fa-circle-check"></i>
      <span>تمت إضافة الصورة بنجاح ${uploadedToStorage ? '(مرفوعة إلى سحابة التخزين)' : ''}!</span>
    `, 'success');
    setTimeout(hideUploadStatus, 4000);

  } catch (err) {
    console.error("Image processing error:", err);
    showUploadStatus(`❌ تعذر معالجة الصورة: ${err.message}`, 'error');
    setTimeout(hideUploadStatus, 5000);
  } finally {
    fileInput.value = "";
  }
}

function compressImageFile(file, maxDimension = 1000, quality = 0.82) {
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

        const dataUrl = canvas.toDataURL("image/jpeg", quality);
        resolve(dataUrl);
      };
      img.onerror = () => reject(new Error("فشل قراءة ملف الصورة"));
      img.src = e.target.result;
    };
    reader.onerror = () => reject(new Error("فشل فتح الملف من جهازك"));
    reader.readAsDataURL(file);
  });
}
