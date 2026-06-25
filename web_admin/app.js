/* ==========================================================================
   APP.JS - LÓGICA DEL PORTAL WEB SICCE
   ========================================================================== */

// Variables de Estado Global
let currentUser = null;
let currentUserRole = null;
let currentUserDisplayName = "";
let currentTeacherUid = null; // Para gestionar asignaciones
let activeClass = null; // Clase seleccionada por el maestro { gradoGrupo, materia }
let allStudents = []; // Cache para el buscador individual
let allGroups = []; // Cache de todos los grupos únicos
let pendingAlerts = []; // Cache de alertas pendientes en memoria
let alertsListenerUnsubscribe = null;

// Inicialización
document.addEventListener("DOMContentLoaded", () => {
  setupAuthListener();
  setupUIEventListeners();
});

// ==========================================================================
// 1. ESCUCHADORES DE AUTENTICACIÓN
// ==========================================================================
function setupAuthListener() {
  auth.onAuthStateChanged(async (user) => {
    const loginContainer = document.getElementById("login-container");
    const appContainer = document.getElementById("app-container");
    
    if (user) {
      currentUser = user;
      document.getElementById("login-spinner").classList.add("hidden");
      
      try {
        // Cargar rol de usuario desde Firestore
        const userDoc = await db.collection("usuarios").doc(user.uid).get();
        
        if (!userDoc.exists) {
          // Si no existe, es un usuario no configurado en roles
          showLoginError("Tu cuenta no tiene un rol asignado en el sistema.");
          auth.signOut();
          return;
        }
        
        const userData = userDoc.data();
        currentUserRole = userData.rol;
        
        if (currentUserRole !== "admin" && currentUserRole !== "maestro") {
          showLoginError("Acceso denegado. Este portal es exclusivo para administradores y maestros.");
          auth.signOut();
          return;
        }
        
        // Configurar UI según el Rol
        setupRoleUI(userData);
        
        // Ocultar login y mostrar dashboard
        loginContainer.classList.add("hidden");
        appContainer.classList.remove("hidden");
        
      } catch (error) {
        console.error("Error al cargar datos del usuario:", error);
        showLoginError("Error de conexión al cargar el perfil.");
        auth.signOut();
      }
    } else {
      currentUser = null;
      currentUserRole = null;
      activeClass = null;
      
      // Mostrar login y ocultar dashboard
      loginContainer.classList.remove("hidden");
      appContainer.classList.add("hidden");
      
      // Resetear campos
      document.getElementById("login-form").reset();
    }
  });
}

// Configurar elementos de UI específicos de cada rol
function setupRoleUI(userData) {
  const navAdminSection = document.getElementById("nav-admin-section");
  const navTeacherSection = document.getElementById("nav-teacher-section");
  
  // Nombre y rol en el Sidebar
  document.getElementById("user-display-name").textContent = userData.nombre || userData.email;
  const roleBadge = document.getElementById("user-display-role");
  roleBadge.textContent = userData.rol === "admin" ? "Administrador" : "Profesor";
  roleBadge.className = `badge ${userData.rol === "admin" ? "badge-admin" : "badge-teacher"}`;
  
  currentUserDisplayName = userData.nombre || userData.email || "Usuario";
  
  // Resetear clases de navegación activas
  document.querySelectorAll(".nav-item").forEach(item => item.classList.remove("active"));
  
  if (userData.rol === "admin") {
    navAdminSection.classList.remove("hidden");
    navTeacherSection.classList.add("hidden");
    
    // Activar pestaña por defecto de admin
    const defaultNavItem = document.querySelector('[data-tab="admin-teachers"]');
    defaultNavItem.classList.add("active");
    switchTab("admin-teachers");
    
    // Cargar datos iniciales de administración
    loadTeachersList();
    loadUniqueGroups();
    loadAdminsList();
    loadAllSchedules();
    loadCalendarEvents();
    loadAdminStudentsList();
    setupAlertsRealtimeListener();
  } else if (userData.rol === "maestro") {
    navAdminSection.classList.add("hidden");
    navTeacherSection.classList.remove("hidden");
    
    // Activar pestaña por defecto de maestro
    const defaultNavItem = document.querySelector('[data-tab="teacher-dashboard"]');
    defaultNavItem.classList.add("active");
    switchTab("teacher-dashboard");
    
    // Cargar salones del maestro
    loadTeacherDashboard();
  }
  
  // Cargar estudiantes para el reporte individual
  cacheAllStudents();
}

// Mostrar error de inicio de sesión
function showLoginError(msg) {
  const errBox = document.getElementById("login-error");
  errBox.textContent = msg;
  errBox.classList.remove("hidden");
}

// ==========================================================================
// 2. ENRUTAMIENTO DE PESTAÑAS (TAB SYSTEM)
// ==========================================================================
function setupUIEventListeners() {
  // Login Form
  document.getElementById("login-form").addEventListener("submit", async (e) => {
    e.preventDefault();
    const email = document.getElementById("login-email").value.trim();
    const pass = document.getElementById("login-password").value;
    const spinner = document.getElementById("login-spinner");
    const errBox = document.getElementById("login-error");
    
    errBox.classList.add("hidden");
    spinner.classList.remove("hidden");
    
    try {
      await auth.signInWithEmailAndPassword(email, pass);
    } catch (error) {
      console.error(error);
      spinner.classList.add("hidden");
      if (error.code === "auth/invalid-credential" || error.code === "auth/wrong-password" || error.code === "auth/user-not-found") {
        showLoginError("Correo o contraseña incorrectos.");
      } else {
        showLoginError("Error al iniciar sesión: " + error.message);
      }
    }
  });
  
  // Cierre de Sesión
  document.getElementById("btn-logout").addEventListener("click", () => {
    if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
      auth.signOut();
    }
  });
  
  // Navegación por pestañas
  document.querySelectorAll(".nav-item").forEach(item => {
    item.addEventListener("click", (e) => {
      e.preventDefault();
      
      document.querySelectorAll(".nav-item").forEach(i => i.classList.remove("active"));
      item.classList.add("active");
      
      const tabId = item.getAttribute("data-tab");
      switchTab(tabId);
    });
  });
  
  // Modales - Botones de abrir/cerrar
  document.getElementById("btn-open-register-teacher").addEventListener("click", () => {
    openModal("modal-register-teacher");
  });
  document.getElementById("btn-open-register-admin").addEventListener("click", () => {
    openModal("modal-register-admin");
  });
  
  document.querySelectorAll(".btn-close-modal").forEach(btn => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      closeAllModals();
    });
  });
  
  // Formularios de Registro (Admin)
  document.getElementById("form-register-teacher").addEventListener("submit", handleRegisterTeacher);
  document.getElementById("form-register-admin").addEventListener("submit", handleRegisterAdmin);
  document.getElementById("form-add-assignment").addEventListener("submit", handleAddAssignment);
  
  // Controles de Toma de Asistencia (Teacher)
  document.getElementById("btn-back-to-classes").addEventListener("click", () => {
    document.getElementById("view-take-attendance").classList.add("hidden");
    document.getElementById("tab-teacher-dashboard").classList.remove("hidden");
    loadTeacherDashboard();
  });
  
  document.getElementById("attendance-date").addEventListener("change", () => {
    if (activeClass) {
      loadClassStudentsForAttendance();
    }
  });
  
  // Modos de Toma de Asistencia (Filtros de Subvista)
  document.getElementById("btn-mode-list").addEventListener("click", (e) => {
    toggleAttendanceMode("daily");
  });
  document.getElementById("btn-mode-weekly").addEventListener("click", (e) => {
    toggleAttendanceMode("weekly");
  });
  document.getElementById("btn-mode-monthly").addEventListener("click", (e) => {
    toggleAttendanceMode("monthly");
  });
  
  document.getElementById("btn-save-attendance").addEventListener("click", saveAttendance);
  document.getElementById("btn-print-grid-report").addEventListener("click", () => window.print());
  
  // Generación de Reportes Grupales (Admin)
  document.getElementById("btn-generate-group-report").addEventListener("click", generateGroupReport);
  document.getElementById("btn-print-group-report").addEventListener("click", () => window.print());
  
  // Buscador de Alumno (Reporte Individual)
  setupStudentSearch();
  document.getElementById("btn-print-student-report").addEventListener("click", () => window.print());

  // Formulario y Filtros Nuevos (Admin)
  document.getElementById("form-add-calendar-event").addEventListener("submit", handleSaveCalendarEvent);
  document.getElementById("students-search-filter").addEventListener("input", filterAdminStudentsList);
  const studentsGroupFilter = document.getElementById("students-filter-group");
  if (studentsGroupFilter) {
    studentsGroupFilter.addEventListener("change", filterAdminStudentsList);
  }
  
  // Filtros de MB160 (Admin)
  const btnFilterMb160 = document.getElementById("btn-filter-mb160");
  if (btnFilterMb160) {
    btnFilterMb160.addEventListener("click", loadAdminMb160Attendance);
  }
  const btnPrintMb160 = document.getElementById("btn-print-mb160");
  if (btnPrintMb160) {
    btnPrintMb160.addEventListener("click", () => window.print());
  }

  // Filtros de MB160 (Teacher)
  const btnModeMb160 = document.getElementById("btn-mode-mb160");
  if (btnModeMb160) {
    btnModeMb160.addEventListener("click", () => toggleAttendanceMode("mb160"));
  }
  const btnPrintTeacherMb160 = document.getElementById("btn-print-teacher-mb160");
  if (btnPrintTeacherMb160) {
    btnPrintTeacherMb160.addEventListener("click", () => window.print());
  }

  // Event Listeners para Alertas (Teacher y Admin)
  const formReport = document.getElementById("form-report-student");
  if (formReport) formReport.addEventListener("submit", handleReportStudentSubmit);
  
  const formSendMsg = document.getElementById("form-send-tutor-message");
  if (formSendMsg) formSendMsg.addEventListener("submit", handleSendTutorMessage);
  
  const btnResolveAlert = document.getElementById("btn-mark-alert-resolved");
  if (btnResolveAlert) btnResolveAlert.addEventListener("click", handleMarkAlertAtendida);
  
  const alertFilter = document.getElementById("alert-type-filter");
  if (alertFilter) alertFilter.addEventListener("change", (e) => renderAlertsTable(e.target.value));
}

function switchTab(tabId) {
  // Ocultar todas las pestañas
  document.querySelectorAll(".tab-pane").forEach(pane => pane.classList.add("hidden"));
  document.getElementById("view-take-attendance").classList.add("hidden");
  
  // Mostrar la pestaña seleccionada
  const activePane = document.getElementById(`tab-${tabId}`);
  if (activePane) {
    activePane.classList.remove("hidden");
  }
  
  if (tabId === "admin-alerts") {
    const filterType = document.getElementById("alert-type-filter").value;
    renderAlertsTable(filterType);
  } else if (tabId === "admin-mb160-attendance") {
    const filterDateInput = document.getElementById("mb160-filter-date");
    if (filterDateInput && !filterDateInput.value) {
      filterDateInput.value = getTodayLocalDate();
    }
    loadAdminMb160Attendance();
  }
}

function openModal(modalId) {
  document.getElementById(modalId).classList.remove("hidden");
}

function closeAllModals() {
  document.querySelectorAll(".modal-overlay").forEach(modal => modal.classList.add("hidden"));
  // Resetear formularios e hilos de error
  document.getElementById("form-register-teacher").reset();
  document.getElementById("form-register-admin").reset();
  document.getElementById("form-add-assignment").reset();
  document.getElementById("register-teacher-error").classList.add("hidden");
  document.getElementById("register-admin-error").classList.add("hidden");
  
  const formReport = document.getElementById("form-report-student");
  if (formReport) formReport.reset();
  const formMsg = document.getElementById("form-send-tutor-message");
  if (formMsg) formMsg.reset();
  
  const errReport = document.getElementById("report-student-error");
  if (errReport) errReport.classList.add("hidden");
  const errMsg = document.getElementById("send-message-error");
  if (errMsg) errMsg.classList.add("hidden");
}

// ==========================================================================
// 3. ACCIONES DE GESTIÓN (ADMINISTRADOR)
// ==========================================================================

// Cargar la lista de profesores en la tabla
async function loadTeachersList() {
  const tbody = document.getElementById("teachers-table-body");
  tbody.innerHTML = '<tr><td colspan="4" class="text-center">Cargando profesores...</td></tr>';
  
  try {
    const snapshot = await db.collection("usuarios").where("rol", "==", "maestro").get();
    
    if (snapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="4" class="text-center">No hay profesores registrados.</td></tr>';
      return;
    }
    
    tbody.innerHTML = "";
    snapshot.forEach(doc => {
      const data = doc.data();
      const tr = document.createElement("tr");
      
      // Formatear asignaciones
      let assignmentsHtml = "";
      if (data.materias && data.materias.length > 0) {
        assignmentsHtml = data.materias.map(m => 
          `<span class="badge badge-teacher" style="margin: 2px;">${m.gradoGrupo} - ${m.materia}</span>`
        ).join(" ");
      } else {
        assignmentsHtml = '<span style="color:#94a3b8; font-style:italic;">Sin asignaciones</span>';
      }
      
      tr.innerHTML = `
        <td><strong>${data.nombre}</strong></td>
        <td>${data.email}</td>
        <td>${assignmentsHtml}</td>
        <td class="actions-col">
          <button class="btn btn-secondary btn-icon" title="Gestionar Asignaciones" onclick="openAssignmentsModal('${doc.id}', '${data.nombre}')">
            <i class="material-icons">edit_calendar</i>
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (error) {
    console.error("Error al cargar profesores:", error);
    tbody.innerHTML = '<tr><td colspan="4" class="text-center error-message">Error al cargar la lista.</td></tr>';
  }
}

// Cargar la lista de administradores en la tabla
async function loadAdminsList() {
  const tbody = document.getElementById("admins-table-body");
  tbody.innerHTML = '<tr><td colspan="3" class="text-center">Cargando administradores...</td></tr>';
  
  try {
    const snapshot = await db.collection("usuarios").where("rol", "==", "admin").get();
    
    tbody.innerHTML = "";
    snapshot.forEach(doc => {
      const data = doc.data();
      const tr = document.createElement("tr");
      const dateStr = data.createdAt ? new Date(data.createdAt.seconds * 1000).toLocaleDateString() : "-";
      
      tr.innerHTML = `
        <td><strong>${data.nombre}</strong></td>
        <td>${data.email}</td>
        <td>${dateStr}</td>
      `;
      tbody.appendChild(tr);
    });
  } catch (error) {
    console.error("Error al cargar administradores:", error);
    tbody.innerHTML = '<tr><td colspan="3" class="text-center error-message">Error al cargar administradores.</td></tr>';
  }
}

// Cargar todos los horarios existentes
async function loadAllSchedules() {
  const tbody = document.getElementById("schedules-table-body");
  tbody.innerHTML = '<tr><td colspan="3" class="text-center">Cargando horarios...</td></tr>';
  
  try {
    const snapshot = await db.collection("usuarios").where("rol", "==", "maestro").get();
    tbody.innerHTML = "";
    let count = 0;
    
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.materias && data.materias.length > 0) {
        data.materias.forEach(m => {
          count++;
          const tr = document.createElement("tr");
          tr.innerHTML = `
            <td><strong>${data.nombre}</strong></td>
            <td><span class="badge badge-teacher">${m.gradoGrupo}</span></td>
            <td>${m.materia}</td>
          `;
          tbody.appendChild(tr);
        });
      }
    });
    
    if (count === 0) {
      tbody.innerHTML = '<tr><td colspan="3" class="text-center">No hay horarios o asignaciones de salones registradas.</td></tr>';
    }
  } catch (error) {
    console.error(error);
    tbody.innerHTML = '<tr><td colspan="3" class="text-center error-message">Error al cargar horarios.</td></tr>';
  }
}

// Carga de grupos únicos desde los datos sincronizados de ZKBioTime
async function loadUniqueGroups() {
  try {
    const snapshot = await db.collection("zktime_empleados").get();
    const groupSet = new Set();
    
    snapshot.forEach(doc => {
      const data = doc.data();
      if (data.gradoGrupo) {
        groupSet.add(data.gradoGrupo.trim());
      }
    });
    
    allGroups = Array.from(groupSet).sort();
    
    // Poblar select del reporte grupal
    const reportSelect = document.getElementById("report-group");
    reportSelect.innerHTML = '<option value="">Seleccione un grupo</option>';
    
    // Poblar select de asignaciones del modal
    const assignSelect = document.getElementById("assign-group");
    assignSelect.innerHTML = '<option value="">Seleccione un grupo</option>';

    // Poblar select de asistencias MB160
    const mb160Select = document.getElementById("mb160-filter-group");
    if (mb160Select) {
      mb160Select.innerHTML = '<option value="">Todos los grupos</option>';
    }
    
    // Poblar select de filtrado de alumnos
    const studentsSelect = document.getElementById("students-filter-group");
    if (studentsSelect) {
      studentsSelect.innerHTML = '<option value="">Todos los grupos</option>';
    }
    
    allGroups.forEach(g => {
      const opt1 = document.createElement("option");
      opt1.value = g;
      opt1.textContent = g;
      reportSelect.appendChild(opt1);
      
      const opt2 = document.createElement("option");
      opt2.value = g;
      opt2.textContent = g;
      assignSelect.appendChild(opt2);

      if (mb160Select) {
        const opt3 = document.createElement("option");
        opt3.value = g;
        opt3.textContent = g;
        mb160Select.appendChild(opt3);
      }
      
      if (studentsSelect) {
        const opt4 = document.createElement("option");
        opt4.value = g;
        opt4.textContent = g;
        studentsSelect.appendChild(opt4);
      }
    });
  } catch (error) {
    console.error("Error al cargar grupos únicos:", error);
  }
}

// Registro de Profesor (Usando Auth Secundaria para no desloguear al Admin)
async function handleRegisterTeacher(e) {
  e.preventDefault();
  const name = document.getElementById("teacher-name").value.trim();
  const email = document.getElementById("teacher-email").value.trim();
  const password = document.getElementById("teacher-password").value;
  const spinner = document.getElementById("register-teacher-spinner");
  const errBox = document.getElementById("register-teacher-error");
  
  spinner.classList.remove("hidden");
  errBox.classList.add("hidden");
  
  // Usar una app secundaria temporal de Firebase para crear el usuario en Auth
  let secondaryApp = null;
  try {
    secondaryApp = firebase.initializeApp(firebaseConfig, "SecondaryAppTeacher");
    const secondaryAuth = secondaryApp.auth();
    
    const credential = await secondaryAuth.createUserWithEmailAndPassword(email, password);
    const uid = credential.user.uid;
    
    // Guardar en la colección 'usuarios'
    await db.collection("usuarios").doc(uid).set({
      nombre: name,
      email: email,
      rol: "maestro",
      materias: [],
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    // Limpieza
    await secondaryAuth.signOut();
    await secondaryApp.delete();
    
    closeAllModals();
    alert(`Profesor registrado exitosamente:\nEmail: ${email}`);
    loadTeachersList();
    loadAllSchedules();
  } catch (error) {
    console.error("Error al registrar profesor:", error);
    spinner.classList.add("hidden");
    errBox.textContent = error.message;
    errBox.classList.remove("hidden");
    if (secondaryApp) {
      await secondaryApp.delete();
    }
  }
}

// Registro de nuevo Administrador
async function handleRegisterAdmin(e) {
  e.preventDefault();
  const name = document.getElementById("admin-name").value.trim();
  const email = document.getElementById("admin-email").value.trim();
  const password = document.getElementById("admin-password").value;
  const spinner = document.getElementById("register-admin-spinner");
  const errBox = document.getElementById("register-admin-error");
  
  spinner.classList.remove("hidden");
  errBox.classList.add("hidden");
  
  let secondaryApp = null;
  try {
    secondaryApp = firebase.initializeApp(firebaseConfig, "SecondaryAppAdmin");
    const secondaryAuth = secondaryApp.auth();
    
    const credential = await secondaryAuth.createUserWithEmailAndPassword(email, password);
    const uid = credential.user.uid;
    
    // Guardar en la colección 'usuarios'
    await db.collection("usuarios").doc(uid).set({
      nombre: name,
      email: email,
      rol: "admin",
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    await secondaryAuth.signOut();
    await secondaryApp.delete();
    
    closeAllModals();
    alert(`Administrador registrado exitosamente:\nEmail: ${email}`);
    loadAdminsList();
  } catch (error) {
    console.error("Error al registrar administrador:", error);
    spinner.classList.add("hidden");
    errBox.textContent = error.message;
    errBox.classList.remove("hidden");
    if (secondaryApp) {
      await secondaryApp.delete();
    }
  }
}

// Gestión de asignaciones de maestro (Abrir Modal)
async function openAssignmentsModal(teacherUid, teacherName) {
  currentTeacherUid = teacherUid;
  document.getElementById("assignment-modal-title").textContent = `Asignaciones: ${teacherName}`;
  
  loadTeacherAssignmentsTable();
  openModal("modal-manage-assignments");
}
window.openAssignmentsModal = openAssignmentsModal; // Exponer para atributo onclick

async function loadTeacherAssignmentsTable() {
  const tbody = document.getElementById("assignments-table-body");
  tbody.innerHTML = '<tr><td colspan="3" class="text-center">Cargando asignaciones...</td></tr>';
  
  try {
    const doc = await db.collection("usuarios").doc(currentTeacherUid).get();
    const data = doc.data();
    
    tbody.innerHTML = "";
    if (data.materias && data.materias.length > 0) {
      data.materias.forEach((m, index) => {
        const tr = document.createElement("tr");
        tr.innerHTML = `
          <td><strong>${m.gradoGrupo}</strong></td>
          <td>${m.materia}</td>
          <td class="actions-col">
            <button class="btn btn-danger btn-icon" title="Eliminar Asignación" onclick="removeAssignment(${index})">
              <i class="material-icons">delete</i>
            </button>
          </td>
        `;
        tbody.appendChild(tr);
      });
    } else {
      tbody.innerHTML = '<tr><td colspan="3" class="text-center">No tiene materias asignadas actualmente.</td></tr>';
    }
  } catch (error) {
    console.error(error);
    tbody.innerHTML = '<tr><td colspan="3" class="text-center error-message">Error al cargar.</td></tr>';
  }
}

// Agregar Asignación a un Maestro
async function handleAddAssignment(e) {
  e.preventDefault();
  const group = document.getElementById("assign-group").value;
  const subject = document.getElementById("assign-subject").value.trim();
  
  if (!currentTeacherUid || !group || !subject) return;
  
  try {
    const newAssignment = { gradoGrupo: group, materia: subject };
    
    await db.collection("usuarios").doc(currentTeacherUid).update({
      materias: firebase.firestore.FieldValue.arrayUnion(newAssignment)
    });
    
    document.getElementById("form-add-assignment").reset();
    loadTeacherAssignmentsTable();
    loadTeachersList();
    loadAllSchedules();
  } catch (error) {
    console.error("Error al guardar asignación:", error);
    alert("Error al guardar asignación: " + error.message);
  }
}

// Eliminar Asignación de un Maestro
async function removeAssignment(index) {
  if (!confirm("¿Estás seguro de que deseas eliminar esta asignación?")) return;
  
  try {
    const docRef = db.collection("usuarios").doc(currentTeacherUid);
    const doc = await docRef.get();
    const materias = doc.data().materias;
    
    // Remover por índice
    materias.splice(index, 1);
    
    await docRef.update({ materias: materias });
    
    loadTeacherAssignmentsTable();
    loadTeachersList();
    loadAllSchedules();
  } catch (error) {
    console.error("Error al eliminar asignación:", error);
    alert("Error al eliminar asignación.");
  }
}
window.removeAssignment = removeAssignment; // Exponer a onclick

// Generación de Reportes Grupales
async function generateGroupReport() {
  const group = document.getElementById("report-group").value;
  const startDate = document.getElementById("report-start-date").value;
  const endDate = document.getElementById("report-end-date").value;
  
  if (!group || !startDate || !endDate) {
    alert("Por favor seleccione un grupo y el rango de fechas completo.");
    return;
  }
  
  const tbody = document.getElementById("group-report-table-body");
  tbody.innerHTML = '<tr><td colspan="6" class="text-center">Generando reporte, por favor espere...</td></tr>';
  document.getElementById("btn-print-group-report").disabled = true;
  
  try {
    // 1. Obtener alumnos en el grupo
    const studentSnapshot = await db.collection("zktime_empleados").where("gradoGrupo", "==", group).get();
    
    if (studentSnapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay alumnos registrados en este grupo.</td></tr>';
      return;
    }
    
    const studentsMap = {};
    studentSnapshot.forEach(doc => {
      const data = doc.data();
      const nombreCompleto = data.nombreCompleto || `${data.nombre} ${data.apellidos}`.strip();
      studentsMap[data.matricula] = {
        matricula: data.matricula,
        nombre: nombreCompleto,
        asistencias: 0,
        retardos: 0,
        faltas: 0
      };
    });
    
    // 2. Obtener registros en el rango de fechas
    const attSnapshot = await db.collection("asistencias_diarias")
      .where("fecha", ">=", startDate)
      .where("fecha", "<=", endDate)
      .get();
      
    attSnapshot.forEach(doc => {
      const data = doc.data();
      const matricula = data.matricula;
      
      // Filtrar en memoria por los alumnos del grupo
      if (studentsMap[matricula]) {
        const estado = data.estado;
        if (estado === "Asistencia") {
          studentsMap[matricula].asistencias++;
        } else if (estado === "Retardo") {
          studentsMap[matricula].retardos++;
        } else if (estado === "Falta") {
          studentsMap[matricula].faltas++;
        }
      }
    });
    
    // 3. Renderizar resultados y estadísticas generales
    tbody.innerHTML = "";
    let totalAsistencias = 0;
    let totalRetardos = 0;
    let totalFaltas = 0;
    
    // Ordenar alumnos por nombre
    const sortedStudents = Object.values(studentsMap).sort((a, b) => a.nombre.localeCompare(b.nombre));
    
    sortedStudents.forEach(s => {
      const totalRecords = s.asistencias + s.retardos + s.faltas;
      // Porcentaje de asistencia: (Asistencias + Retardos) / Total
      let percentStr = "-";
      if (totalRecords > 0) {
        const percent = ((s.asistencias + s.retardos) / totalRecords) * 100;
        percentStr = `${Math.round(percent)}%`;
      }
      
      totalAsistencias += s.asistencias;
      totalRetardos += s.retardos;
      totalFaltas += s.faltas;
      
      const tr = document.createElement("tr");
      tr.innerHTML = `
        <td>${s.matricula}</td>
        <td><strong>${s.nombre}</strong></td>
        <td style="color:var(--color-success)">${s.asistencias}</td>
        <td style="color:var(--color-warning)">${s.retardos}</td>
        <td style="color:var(--color-danger)">${s.faltas}</td>
        <td><strong>${percentStr}</strong></td>
      `;
      tbody.appendChild(tr);
    });
    
    // Actualizar cajas de estadísticas
    document.getElementById("group-stat-asistencias").textContent = totalAsistencias;
    document.getElementById("group-stat-retardos").textContent = totalRetardos;
    document.getElementById("group-stat-faltas").textContent = totalFaltas;
    
    // Encabezado para impresión
    document.getElementById("report-meta-text").textContent = `Grupo/Salón: ${group} | Periodo: ${formatDateToShow(startDate)} al ${formatDateToShow(endDate)}`;
    
    // Mostrar resultados
    document.getElementById("group-report-result").classList.remove("hidden");
    document.getElementById("btn-print-group-report").disabled = false;
    
  } catch (error) {
    console.error("Error al generar reporte grupal:", error);
    tbody.innerHTML = '<tr><td colspan="6" class="text-center error-message">Ocurrió un error al generar el reporte.</td></tr>';
  }
}

// ==========================================================================
// 4. FLUJO DE PROFESORES (TEACHER ACTIONS)
// ==========================================================================

// Carga de la cuadrícula de salones asignados al profesor
async function loadTeacherDashboard() {
  const grid = document.getElementById("teacher-classes-grid");
  grid.innerHTML = '<div class="text-center grid-full">Cargando tus salones asignados...</div>';
  
  try {
    const doc = await db.collection("usuarios").doc(currentUser.uid).get();
    const data = doc.data();
    
    grid.innerHTML = "";
    if (data.materias && data.materias.length > 0) {
      data.materias.forEach(m => {
        const card = document.createElement("div");
        card.className = "class-card";
        card.innerHTML = `
          <div class="class-card-header">
            <span class="class-group-badge">${m.gradoGrupo}</span>
            <i class="material-icons class-icon">class</i>
          </div>
          <div class="class-card-info">
            <h3>${m.materia}</h3>
            <p>Colegio de Bachilleres</p>
          </div>
          <div class="class-card-footer">
            <i class="material-icons">fingerprint</i>
            <span>Tomar Asistencia</span>
          </div>
        `;
        
        card.addEventListener("click", () => {
          openClassAttendance(m);
        });
        grid.appendChild(card);
      });
    } else {
      grid.innerHTML = `
        <div class="text-center grid-full">
          <i class="material-icons" style="font-size: 48px; color: #cbd5e1; margin-bottom: 10px;">event_busy</i>
          <p>No tienes materias o salones asignados por el administrador.</p>
        </div>
      `;
    }
  } catch (error) {
    console.error(error);
    grid.innerHTML = '<div class="text-center grid-full error-message">Error al cargar tus salones.</div>';
  }
}

// Abrir la vista para tomar asistencia a una clase específica
function openClassAttendance(materiaObj) {
  activeClass = materiaObj;
  
  // Cambiar vistas
  document.getElementById("tab-teacher-dashboard").classList.add("hidden");
  document.getElementById("view-take-attendance").classList.remove("hidden");
  
  // Establecer títulos
  document.getElementById("attendance-class-title").textContent = `Grupo/Salón: ${materiaObj.gradoGrupo}`;
  document.getElementById("attendance-class-subtitle").textContent = `Materia: ${materiaObj.materia}`;
  
  // Establecer fecha por defecto a hoy local
  const today = getTodayLocalDate();
  document.getElementById("attendance-date").value = today;
  
  // Cargar en vista diaria por defecto
  toggleAttendanceMode("daily");
}

function toggleAttendanceMode(mode) {
  // Ajustar botones de modo
  document.getElementById("btn-mode-list").classList.remove("active");
  document.getElementById("btn-mode-weekly").classList.remove("active");
  document.getElementById("btn-mode-monthly").classList.remove("active");
  
  const btnModeMb160 = document.getElementById("btn-mode-mb160");
  if (btnModeMb160) btnModeMb160.classList.remove("active");
  
  document.getElementById("subview-daily-list").classList.add("hidden");
  document.getElementById("subview-history-grid").classList.add("hidden");
  
  const subviewMb160 = document.getElementById("subview-teacher-mb160");
  if (subviewMb160) subviewMb160.classList.add("hidden");
  
  if (mode === "daily") {
    document.getElementById("btn-mode-list").classList.add("active");
    document.getElementById("subview-daily-list").classList.remove("hidden");
    loadClassStudentsForAttendance();
  } else if (mode === "weekly") {
    document.getElementById("btn-mode-weekly").classList.add("active");
    document.getElementById("subview-history-grid").classList.remove("hidden");
    loadHistoryGrid("weekly");
  } else if (mode === "monthly") {
    document.getElementById("btn-mode-monthly").classList.add("active");
    document.getElementById("subview-history-grid").classList.remove("hidden");
    loadHistoryGrid("monthly");
  } else if (mode === "mb160") {
    if (btnModeMb160) btnModeMb160.classList.add("active");
    if (subviewMb160) subviewMb160.classList.remove("hidden");
    loadTeacherMb160Attendance();
  }
}

// Cargar lista diaria de alumnos para tomar asistencia
async function loadClassStudentsForAttendance() {
  const tbody = document.getElementById("attendance-students-body");
  tbody.innerHTML = '<tr><td colspan="3" class="text-center">Cargando alumnos...</td></tr>';
  
  const fecha = document.getElementById("attendance-date").value;
  if (!fecha) return;
  
  try {
    // 1. Obtener alumnos en este salón
    const studentSnapshot = await db.collection("zktime_empleados").where("gradoGrupo", "==", activeClass.gradoGrupo).get();
    
    if (studentSnapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="3" class="text-center">No hay alumnos asignados a este grupo en el biométrico.</td></tr>';
      return;
    }
    
    // 2. Obtener asistencias ya guardadas para este salón y esta fecha
    const attendanceSnapshot = await db.collection("asistencias_diarias")
      .where("fecha", "==", fecha)
      .get();
      
    const savedRecords = {};
    attendanceSnapshot.forEach(doc => {
      const data = doc.data();
      savedRecords[data.matricula] = data; // Guardamos el registro completo
    });
    
    // 3. Renderizar la tabla de alumnos
    tbody.innerHTML = "";
    
    // Guardar estudiantes de forma ordenada por nombre
    const students = [];
    studentSnapshot.forEach(doc => {
      students.push(doc.data());
    });
    students.sort((a, b) => {
      const nameA = a.nombreCompleto || `${a.nombre} ${a.apellidos}`;
      const nameB = b.nombreCompleto || `${b.nombre} ${b.apellidos}`;
      return nameA.localeCompare(nameB);
    });
    
    students.forEach(student => {
      const matricula = student.matricula;
      const name = student.nombreCompleto || `${student.nombre} ${student.apellidos}`;
      
      // Obtener el registro preexistente si lo hay
      const savedRecord = savedRecords[matricula];
      // Por defecto si no tiene registro, el estado es "Falta"
      const estadoActual = savedRecord ? savedRecord.estado : "Falta";
      
      // Construir badge con hora y origen si existe
      let infoBadge = "";
      if (savedRecord && savedRecord.entrada) {
        const timeFmt = savedRecord.entrada.substring(0, 5); // HH:MM
        const esBio = (savedRecord.origen || "").toLowerCase().includes("biom") || (savedRecord.origen || "").includes("MB160");
        const icon = esBio ? "fingerprint" : "language";
        const label = esBio ? "Biométrico" : "Portal";
        const badgeColor = esBio 
          ? "background-color: rgba(16, 185, 129, 0.1); color: var(--color-success); border: 1px solid rgba(16, 185, 129, 0.2);" 
          : "background-color: rgba(30, 64, 175, 0.1); color: var(--color-primary); border: 1px solid rgba(30, 64, 175, 0.2);";
        
        infoBadge = `
          <div style="margin-top: 4px; display: inline-flex; align-items: center; gap: 4px; font-size: 0.75rem; padding: 2px 6px; border-radius: 4px; ${badgeColor}">
            <i class="material-icons" style="font-size: 12px;">${icon}</i>
            <span>${label}: ${timeFmt}</span>
          </div>
        `;
      }
      
      const tr = document.createElement("tr");
      // Almacenar valores originales para preservarlos en el guardado
      tr.setAttribute("data-entrada", savedRecord ? (savedRecord.entrada || "") : "");
      tr.setAttribute("data-salida", savedRecord ? (savedRecord.salida || "") : "");
      tr.setAttribute("data-origen", savedRecord ? (savedRecord.origen || "") : "");
      
      tr.innerHTML = `
        <td>${matricula}</td>
        <td>
          <div style="display: flex; flex-direction: column;">
            <strong>${name}</strong>
            ${infoBadge}
          </div>
        </td>
        <td class="status-selection-header">
          <div class="status-selection">
            <label class="radio-status status-asistencia">
              <input type="radio" name="status_${matricula}" value="Asistencia" ${estadoActual === "Asistencia" ? "checked" : ""}>
              <span>Asistencia</span>
            </label>
            <label class="radio-status status-retardo">
              <input type="radio" name="status_${matricula}" value="Retardo" ${estadoActual === "Retardo" ? "checked" : ""}>
              <span>Retardo</span>
            </label>
            <label class="radio-status status-falta">
              <input type="radio" name="status_${matricula}" value="Falta" ${estadoActual === "Falta" ? "checked" : ""}>
              <span>Falta</span>
            </label>
          </div>
        </td>
        <td style="text-align: center;">
          <button type="button" class="btn btn-warning-outline" onclick="openReportStudentModal('${matricula}', '${name.replace(/'/g, "\\'")}', '${student.grado || ""}', '${student.grupo || ""}')" title="Reportar alumno con faltas">
            <i class="material-icons" style="font-size: 18px;">report_problem</i>
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (error) {
    console.error("Error al cargar lista de asistencia diaria:", error);
    tbody.innerHTML = '<tr><td colspan="3" class="text-center error-message">Error al cargar la lista de alumnos.</td></tr>';
  }
}

// Guardar los registros de asistencia diaria
async function saveAttendance() {
  const tbody = document.getElementById("attendance-students-body");
  const rows = tbody.querySelectorAll("tr");
  const fecha = document.getElementById("attendance-date").value;
  const statusMsg = document.getElementById("attendance-save-status");
  
  if (!fecha || rows.length === 0) return;
  
  statusMsg.className = "status-msg";
  statusMsg.textContent = "Guardando asistencias...";
  statusMsg.classList.remove("hidden");
  
  try {
    const timeStr = getCurrentTime();
    
    // Batch Firestore writing
    const batch = db.batch();
    
    for (let row of rows) {
      const tds = row.querySelectorAll("td");
      if (tds.length < 3) continue; // Si es un mensaje cargando
      
      const matricula = tds[0].textContent;
      const nombre = tds[1].querySelector("strong").textContent;
      
      const existingEntrada = row.getAttribute("data-entrada");
      const existingSalida = row.getAttribute("data-salida");
      const existingOrigen = row.getAttribute("data-origen");
      
      const radioInput = row.querySelector(`input[name="status_${matricula}"]:checked`);
      if (!radioInput) continue;
      const estado = radioInput.value; // "Asistencia", "Retardo", "Falta"
      
      let finalEntrada = existingEntrada;
      let finalSalida = existingSalida;
      let finalOrigen = existingOrigen || "Web Portal Maestro";
      
      if (estado === "Falta") {
        finalEntrada = "";
        finalSalida = "";
        finalOrigen = "Web Portal Maestro";
      } else {
        // Si no tenía hora de entrada previa (o si era Falta), le asignamos la hora actual
        if (!finalEntrada) {
          finalEntrada = timeStr;
          finalOrigen = "Web Portal Maestro";
        }
      }
      
      // 1. Guardar en 'asistencias_diarias' (ID unico: matricula_fecha)
      const docDiarioId = `${matricula}_${fecha}`;
      const docDiarioRef = db.collection("asistencias_diarias").doc(docDiarioId);
      
      batch.set(docDiarioRef, {
        matricula: matricula,
        nombre: nombre,
        fecha: fecha,
        entrada: finalEntrada,
        salida: finalSalida,
        estado: estado,
        origen: finalOrigen,
        fechaSincronizacion: firebase.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
      
      // 2. Si el alumno asistió o tuvo retardo, y no tenía entrada previa, añadir registro a 'asistencias' (sincronizado con app movil)
      if (estado !== "Falta" && !existingEntrada) {
        const zkId = `web_${matricula}_${fecha}_${timeStr.replace(/:/g, '')}`;
        const docRefTrans = db.collection("asistencias").doc(zkId);
        
        // Buscar grado/grupo del alumno en caché global si es posible
        const cachedStudent = allStudents.find(s => s.matricula === matricula) || {};
        
        batch.set(docRefTrans, {
          zk_id: zkId,
          matricula: matricula,
          matriculaAlumno: matricula,
          nombre: nombre,
          nombreAlumno: nombre,
          grado: cachedStudent.grado || (activeClass ? activeClass.gradoGrupo.substring(0, 1) : ""),
          grupo: cachedStudent.grupo || (activeClass ? activeClass.gradoGrupo.substring(1) : ""),
          fecha: fecha,
          hora: finalEntrada,
          tipoRegistro: "entrada",
          fechaHora: `${fecha} ${finalEntrada}`,
          origen: "Web Portal Maestro",
          fechaSincronizacion: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
      }
    }
    
    await batch.commit();
    
    statusMsg.className = "status-msg success";
    statusMsg.textContent = "¡Asistencia guardada exitosamente!";
    setTimeout(() => statusMsg.classList.add("hidden"), 3000);
    
    // Recargar tabla para reflejar los nuevos badges/datos guardados
    loadClassStudentsForAttendance();
    
  } catch (error) {
    console.error("Error al guardar asistencias:", error);
    statusMsg.className = "status-msg error";
    statusMsg.textContent = "Error al guardar asistencias: " + error.message;
  }
}

// Cargar cuadrícula histórica (Semanal o Mensual)
async function loadHistoryGrid(type) {
  const table = document.getElementById("history-grid-table");
  table.innerHTML = '<tr><td class="text-center">Cargando cuadrícula...</td></tr>';
  
  const referenceDateVal = document.getElementById("attendance-date").value;
  if (!referenceDateVal || !activeClass) return;
  
  const referenceDate = new Date(referenceDateVal + "T00:00:00");
  
  let dateList = [];
  let startDate = "";
  let endDate = "";
  
  if (type === "weekly") {
    // Calcular Lunes a Viernes de la semana seleccionada
    const currentDay = referenceDate.getDay(); // 0: Dom, 1: Lun, ...
    const distanceToMonday = currentDay === 0 ? -6 : 1 - currentDay;
    
    const monday = new Date(referenceDate);
    monday.setDate(referenceDate.getDate() + distanceToMonday);
    
    for (let i = 0; i < 5; i++) {
      const d = new Date(monday);
      d.setDate(monday.getDate() + i);
      dateList.push(formatDateToIso(d));
    }
    
    startDate = dateList[0];
    endDate = dateList[4];
    document.getElementById("history-grid-title").textContent = `Registro Semanal (${formatDateToShow(startDate)} al ${formatDateToShow(endDate)})`;
  } else {
    // Mensual
    const year = referenceDate.getFullYear();
    const month = referenceDate.getMonth(); // 0-11
    
    // Obtener días del mes
    const lastDay = new Date(year, month + 1, 0).getDate();
    
    for (let i = 1; i <= lastDay; i++) {
      const d = new Date(year, month, i);
      // Excluir fines de semana de las columnas para limpieza
      if (d.getDay() !== 0 && d.getDay() !== 6) {
        dateList.push(formatDateToIso(d));
      }
    }
    
    startDate = dateList[0];
    endDate = dateList[dateList.length - 1];
    
    const monthNames = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"];
    document.getElementById("history-grid-title").textContent = `Registro Mensual - ${monthNames[month]} ${year}`;
  }
  
  try {
    // 1. Cargar Alumnos
    const studentSnapshot = await db.collection("zktime_empleados").where("gradoGrupo", "==", activeClass.gradoGrupo).get();
    if (studentSnapshot.empty) {
      table.innerHTML = '<tr><td class="text-center">No hay alumnos en el grupo.</td></tr>';
      return;
    }
    
    const students = [];
    studentSnapshot.forEach(doc => {
      students.push(doc.data());
    });
    students.sort((a, b) => {
      const nameA = a.nombreCompleto || `${a.nombre} ${a.apellidos}`;
      const nameB = b.nombreCompleto || `${b.nombre} ${b.apellidos}`;
      return nameA.localeCompare(nameB);
    });
    
    // 2. Cargar Asistencias
    const attSnapshot = await db.collection("asistencias_diarias")
      .where("fecha", ">=", startDate)
      .where("fecha", "<=", endDate)
      .get();
      
    // Estructurar asistencias en mapa indexado por [matricula][fecha]
    const attGrid = {};
    attSnapshot.forEach(doc => {
      const data = doc.data();
      const matricula = data.matricula;
      if (!attGrid[matricula]) attGrid[matricula] = {};
      attGrid[matricula][data.fecha] = data.estado; // "Asistencia", "Retardo", "Falta"
    });
    
    // 3. Generar la Cabecera de la Tabla
    let headHtml = "<thead><tr><th>Alumno</th>";
    dateList.forEach(d => {
      const dayNum = d.split("-")[2];
      const dayNameShort = getDayNameShort(d);
      headHtml += `<th title="${d}">${dayNameShort}<br>${dayNum}</th>`;
    });
    headHtml += "</tr></thead>";
    
    // 4. Generar Filas
    let bodyHtml = "<tbody>";
    students.forEach(s => {
      const name = s.nombreCompleto || `${s.nombre} ${s.apellidos}`;
      bodyHtml += `<tr><td class="cell-student-name" title="${name}"><strong>${name}</strong></td>`;
      
      dateList.forEach(d => {
        const state = (attGrid[s.matricula] && attGrid[s.matricula][d]) ? attGrid[s.matricula][d] : "";
        let iconHtml = '<span class="grid-cell-indicator indicator-vacio">-</span>';
        
        if (state === "Asistencia") {
          iconHtml = '<span class="grid-cell-indicator indicator-asistencia" title="Asistencia">✓</span>';
        } else if (state === "Retardo") {
          iconHtml = '<span class="grid-cell-indicator indicator-retardo" title="Retardo">R</span>';
        } else if (state === "Falta") {
          iconHtml = '<span class="grid-cell-indicator indicator-falta" title="Falta">F</span>';
        }
        
        bodyHtml += `<td>${iconHtml}</td>`;
      });
      bodyHtml += "</tr>";
    });
    bodyHtml += "</tbody>";
    
    table.innerHTML = headHtml + bodyHtml;
  } catch (error) {
    console.error("Error al cargar cuadrícula histórica:", error);
    table.innerHTML = '<tr><td class="text-center error-message">Error al cargar los registros.</td></tr>';
  }
}

// ==========================================================================
// 5. REPORTE DETALLADO POR ALUMNO (BUSCADOR INDIVIDUAL)
// ==========================================================================

// Descarga en memoria una lista rápida de todos los alumnos para Autocompletar
async function cacheAllStudents() {
  try {
    const snapshot = await db.collection("zktime_empleados").get();
    allStudents = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const name = data.nombreCompleto || `${data.nombre} ${data.apellidos}`;
      allStudents.push({
        matricula: data.matricula,
        nombre: name,
        gradoGrupo: data.gradoGrupo || "-",
        correo: data.correo || "Sin correo",
        estadoHuella: data.estadoHuella || "No registrada"
      });
    });
    
    // Ordenar por nombre
    allStudents.sort((a, b) => a.nombre.localeCompare(b.nombre));
  } catch (error) {
    console.error("Error al cachear estudiantes:", error);
  }
}

function setupStudentSearch() {
  const searchInput = document.getElementById("student-search-query");
  const autoBox = document.getElementById("search-autocomplete-box");
  
  searchInput.addEventListener("input", () => {
    const query = searchInput.value.trim().toLowerCase();
    
    if (query.length < 2) {
      autoBox.classList.add("hidden");
      return;
    }
    
    // Filtrar alumnos cacheados
    const matches = allStudents.filter(s => 
      s.matricula.toLowerCase().includes(query) || 
      s.nombre.toLowerCase().includes(query)
    ).slice(0, 8); // Mostrar máximo 8 coincidencias
    
    if (matches.length === 0) {
      autoBox.innerHTML = '<div class="autocomplete-item"><span style="color:#94a3b8; font-style:italic;">No hay resultados</span></div>';
      autoBox.classList.remove("hidden");
      return;
    }
    
    autoBox.innerHTML = "";
    matches.forEach(s => {
      const item = document.createElement("div");
      item.className = "autocomplete-item";
      item.innerHTML = `
        <div class="student-info">
          <span class="student-name">${s.nombre}</span>
          <span class="student-meta">Matrícula: ${s.matricula} | Grupo: ${s.gradoGrupo}</span>
        </div>
        <span class="badge badge-teacher">${s.gradoGrupo}</span>
      `;
      
      item.addEventListener("click", () => {
        searchInput.value = s.nombre;
        autoBox.classList.add("hidden");
        loadIndividualStudentReport(s);
      });
      
      autoBox.appendChild(item);
    });
    
    autoBox.classList.remove("hidden");
  });
  
  // Cerrar caja al dar click fuera
  document.addEventListener("click", (e) => {
    if (e.target !== searchInput && e.target !== autoBox) {
      autoBox.classList.add("hidden");
    }
  });
}

// Carga el reporte individual del alumno seleccionado
async function loadIndividualStudentReport(student) {
  // Rellenar Ficha Perfil Alumno
  document.getElementById("student-report-name").textContent = student.nombre;
  document.getElementById("student-report-matricula").textContent = student.matricula;
  document.getElementById("student-report-group").textContent = student.gradoGrupo;
  document.getElementById("student-report-email").textContent = student.correo;
  document.getElementById("student-report-fingerprint").textContent = student.estadoHuella;
  
  // Fecha actual para membrete de impresion
  const now = new Date();
  document.getElementById("student-report-date-text").textContent = `Fecha de Generación: ${now.toLocaleDateString()} a las ${now.toLocaleTimeString()}`;
  
  const tbody = document.getElementById("student-report-table-body");
  tbody.innerHTML = '<tr><td colspan="5" class="text-center">Consultando asistencias en la base de datos...</td></tr>';
  document.getElementById("btn-print-student-report").disabled = true;
  
  try {
    // Consultar asistencias del alumno
    const snapshot = await db.collection("asistencias_diarias")
      .where("matricula", "==", student.matricula)
      .get();
      
    tbody.innerHTML = "";
    
    let aCount = 0;
    let rCount = 0;
    let fCount = 0;
    
    if (snapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center">No hay registros de asistencias en el sistema para este alumno.</td></tr>';
      
      document.getElementById("student-stat-asistencias").textContent = 0;
      document.getElementById("student-stat-retardos").textContent = 0;
      document.getElementById("student-stat-faltas").textContent = 0;
      document.getElementById("student-stat-percent").textContent = "0%";
      document.getElementById("student-report-result").classList.remove("hidden");
      return;
    }
    
    // Convert to array and sort in-memory
    const docs = [];
    snapshot.forEach(doc => {
      docs.push({ id: doc.id, ...doc.data() });
    });
    docs.sort((a, b) => b.fecha.localeCompare(a.fecha));
    
    docs.forEach(data => {
      const estado = data.estado;
      
      if (estado === "Asistencia") aCount++;
      else if (estado === "Retardo") rCount++;
      else if (estado === "Falta") fCount++;
      
      const tr = document.createElement("tr");
      
      let stateColor = "";
      if (estado === "Asistencia") stateColor = 'style="color:var(--color-success); font-weight:600;"';
      else if (estado === "Retardo") stateColor = 'style="color:var(--color-warning); font-weight:600;"';
      else if (estado === "Falta") stateColor = 'style="color:var(--color-danger); font-weight:600;"';
      
      tr.innerHTML = `
        <td><strong>${formatDateToShow(data.fecha)}</strong></td>
        <td>${data.entrada || "-"}</td>
        <td>${data.salida || "-"}</td>
        <td ${stateColor}>${estado}</td>
        <td style="color:#64748b; font-size:0.8rem;">${data.origen || "Desconocido"}</td>
      `;
      tbody.appendChild(tr);
    });
    
    // Asignar estadísticas
    document.getElementById("student-stat-asistencias").textContent = aCount;
    document.getElementById("student-stat-retardos").textContent = rCount;
    document.getElementById("student-stat-faltas").textContent = fCount;
    
    const total = aCount + rCount + fCount;
    let percent = 100;
    if (total > 0) {
      percent = ((aCount + rCount) / total) * 100;
    }
    document.getElementById("student-stat-percent").textContent = `${Math.round(percent)}%`;
    
    // Mostrar reporte e imprimir habilitado
    document.getElementById("student-report-result").classList.remove("hidden");
    document.getElementById("btn-print-student-report").disabled = false;
    
  } catch (error) {
    console.error("Error al cargar reporte individual:", error);
    tbody.innerHTML = '<tr><td colspan="5" class="text-center error-message">Error en base de datos al realizar la consulta.</td></tr>';
  }
}

// ==========================================================================
// HELPER FUNCTIONS (FECHAS Y FORMATOS)
// ==========================================================================

function getTodayLocalDate() {
  const d = new Date();
  return formatDateToIso(d);
}

function formatDateToIso(d) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

function formatDateToShow(dateStr) {
  if (!dateStr) return "";
  const parts = dateStr.split("-");
  if (parts.length !== 3) return dateStr;
  return `${parts[2]}/${parts[1]}/${parts[0]}`;
}

function getCurrentTime() {
  const now = new Date();
  const h = String(now.getHours()).padStart(2, '0');
  const m = String(now.getMinutes()).padStart(2, '0');
  const s = String(now.getSeconds()).padStart(2, '0');
  return `${h}:${m}:${s}`;
}

function getDayNameShort(dateStr) {
  const days = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
  const d = new Date(dateStr + "T00:00:00");
  return days[d.getDay()];
}

// ==========================================================================
// 6. GESTIÓN DE CALENDARIO ESCOLAR (ADMIN)
// ==========================================================================
async function loadCalendarEvents() {
  const tbody = document.getElementById("calendar-events-table-body");
  tbody.innerHTML = '<tr><td colspan="4" class="text-center">Cargando eventos...</td></tr>';
  
  try {
    const snapshot = await db.collection("calendario").orderBy("fecha", "asc").get();
    
    if (snapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="4" class="text-center">No hay eventos escolares registrados.</td></tr>';
      return;
    }
    
    tbody.innerHTML = "";
    snapshot.forEach(doc => {
      const data = doc.data();
      const tr = document.createElement("tr");
      
      let typeLabel = "";
      let typeClass = "";
      if (data.tipo === "suspension") {
        typeLabel = "Suspensión de clases";
        typeClass = "badge badge-admin";
      } else if (data.tipo === "puente") {
        typeLabel = "Puente";
        typeClass = "badge badge-teacher";
      } else {
        typeLabel = "Festivo";
        typeClass = "badge";
      }
      
      tr.innerHTML = `
        <td><strong>${formatDateToShow(data.fecha)}</strong></td>
        <td><span class="${typeClass}">${typeLabel}</span></td>
        <td>${data.descripcion}</td>
        <td class="actions-col">
          <button class="btn btn-danger btn-icon" title="Eliminar Evento" onclick="deleteCalendarEvent('${doc.id}')">
            <i class="material-icons">delete</i>
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });
  } catch (error) {
    console.error("Error al cargar eventos de calendario:", error);
    tbody.innerHTML = '<tr><td colspan="4" class="text-center error-message">Error al cargar el calendario.</td></tr>';
  }
}

async function handleSaveCalendarEvent(e) {
  e.preventDefault();
  const fecha = document.getElementById("calendar-event-date").value;
  const tipo = document.getElementById("calendar-event-type").value;
  const descripcion = document.getElementById("calendar-event-desc").value.trim();
  
  if (!fecha || !tipo || !descripcion) return;
  
  try {
    await db.collection("calendario").doc(fecha).set({
      fecha: fecha,
      tipo: tipo,
      descripcion: descripcion,
      createdAt: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    document.getElementById("form-add-calendar-event").reset();
    loadCalendarEvents();
  } catch (error) {
    console.error("Error al registrar evento:", error);
    alert("Error al guardar evento de calendario: " + error.message);
  }
}

async function deleteCalendarEvent(fecha) {
  if (!confirm(`¿Estás seguro de que deseas eliminar el evento del día ${formatDateToShow(fecha)}?`)) return;
  
  try {
    await db.collection("calendario").doc(fecha).delete();
    loadCalendarEvents();
  } catch (error) {
    console.error("Error al eliminar evento:", error);
    alert("Error al eliminar evento.");
  }
}
window.deleteCalendarEvent = deleteCalendarEvent; // Exponer a click

// ==========================================================================
// 7. GESTIÓN DE DIRECTORIO DE ALUMNOS (ADMIN)
// ==========================================================================
let studentsDirectory = []; // Caché en memoria para filtros rápidos

async function loadAdminStudentsList() {
  const tbody = document.getElementById("admin-students-table-body");
  tbody.innerHTML = '<tr><td colspan="8" class="text-center">Cargando catálogo de alumnos...</td></tr>';
  
  try {
    const snapshot = await db.collection("zktime_empleados").get();
    
    studentsDirectory = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const nombreCompleto = data.nombreCompleto || `${data.nombre} ${data.apellidos}`.trim();
      studentsDirectory.push({
        matricula: data.matricula,
        nombre: nombreCompleto,
        gradoGrupo: data.gradoGrupo || "-",
        correo: data.correo || "Sin correo",
        telefono: data.telefono || "Sin teléfono",
        direccion: data.direccion || "Sin dirección",
        estadoHuella: data.estadoHuella || "No registrada",
        padreId: data.padreId || ""
      });
    });
    
    // Ordenar por grado/grupo, y luego por nombre alfabéticamente
    studentsDirectory.sort((a, b) => {
      const ggA = a.gradoGrupo || "";
      const ggB = b.gradoGrupo || "";
      const compGG = ggA.localeCompare(ggB);
      if (compGG !== 0) return compGG;
      return a.nombre.localeCompare(b.nombre);
    });
    
    renderAdminStudentsTable(studentsDirectory);
  } catch (error) {
    console.error("Error al cargar estudiantes en panel admin:", error);
    tbody.innerHTML = '<tr><td colspan="8" class="text-center error-message">Error de conexión al cargar la lista.</td></tr>';
  }
}

function renderAdminStudentsTable(list) {
  const tbody = document.getElementById("admin-students-table-body");
  
  if (list.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="text-center">No hay alumnos que coincidan con la búsqueda.</td></tr>';
    return;
  }
  
  tbody.innerHTML = "";
  list.forEach(s => {
    const tr = document.createElement("tr");
    
    // Badge de tutor
    const tutorHtml = s.padreId 
      ? `<span class="badge" style="background-color:rgba(16,185,129,0.1); color:var(--color-success)">Vinculado</span>`
      : `<span class="badge" style="background-color:#f1f5f9; color:#94a3b8">Sin Vincular</span>`;
      
    // Badge de huella
    const huellaColor = s.estadoHuella === "registrada" ? "var(--color-success)" : "var(--color-accent)";
    
    tr.innerHTML = `
      <td><strong>${s.matricula}</strong></td>
      <td>${s.nombre}</td>
      <td><span class="badge badge-teacher">${s.gradoGrupo}</span></td>
      <td>
        <div style="font-size:0.8rem; color:#475569;">
          <div><i class="material-icons" style="font-size:12px; vertical-align:middle;">email</i> ${s.correo}</div>
          <div><i class="material-icons" style="font-size:12px; vertical-align:middle;">phone</i> ${s.telefono}</div>
        </div>
      </td>
      <td style="font-size:0.8rem; max-width:200px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;" title="${s.direccion}">${s.direccion}</td>
      <td>
        <span style="font-weight:600; color:${huellaColor}; display:inline-flex; align-items:center; gap:3px;">
          <i class="material-icons" style="font-size:16px;">fingerprint</i> ${s.estadoHuella}
        </span>
      </td>
      <td>${tutorHtml}</td>
      <td>
        <button type="button" class="btn btn-danger-outline" onclick="darDeBajaAlumno('${s.matricula}', '${s.nombre.replace(/'/g, "\\'")}')" title="Dar de baja alumno" style="padding: 6px 10px; font-size: 0.8rem; display: flex; align-items: center; gap: 4px;">
          <i class="material-icons" style="font-size: 16px;">person_remove</i> Baja
        </button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

function filterAdminStudentsList() {
  const searchVal = document.getElementById("students-search-filter").value.trim().toLowerCase();
  const groupVal = document.getElementById("students-filter-group") ? document.getElementById("students-filter-group").value : "";
  
  let filtered = studentsDirectory;
  
  // Filtrar por grupo
  if (groupVal) {
    filtered = filtered.filter(s => s.gradoGrupo === groupVal);
  }
  
  // Filtrar por buscador
  if (searchVal) {
    filtered = filtered.filter(s => 
      s.matricula.toLowerCase().includes(searchVal) ||
      s.nombre.toLowerCase().includes(searchVal) ||
      s.correo.toLowerCase().includes(searchVal)
    );
  }
  
  renderAdminStudentsTable(filtered);
}

// Dar de baja a un alumno de manera permanente
async function darDeBajaAlumno(matricula, nombre) {
  if (!confirm(`¿Estás seguro de que deseas dar de baja al alumno "${nombre}" con matrícula ${matricula}?\n\nEsta acción lo eliminará de forma permanente de la base de datos web y del biométrico ZKBioTime.`)) {
    return;
  }
  
  try {
    // 1. Agregar a la colección de bajas_pendientes en Firestore
    await db.collection("bajas_pendientes").doc(matricula).set({
      matricula: matricula,
      nombre: nombre,
      fechaSolicitud: firebase.firestore.FieldValue.serverTimestamp(),
      estado: "pendiente"
    });
    
    alert(`Se ha solicitado la baja de ${nombre}. El biométrico y Firebase se sincronizarán en unos segundos.`);
    
    // Recargar la lista localmente quitándolo de la lista de visualización para dar feedback inmediato
    studentsDirectory = studentsDirectory.filter(s => s.matricula !== matricula);
    filterAdminStudentsList();
    
  } catch (error) {
    console.error("Error al solicitar baja del alumno:", error);
    alert("Error al solicitar la baja del alumno: " + error.message);
  }
}

// Exponer la función globalmente
window.darDeBajaAlumno = darDeBajaAlumno;

// ==========================================================================
// 8. MÓDULO DE ALERTAS ESCOLARES
// ==========================================================================

// --- PROFESORES: Reportar Alumno ---
function openReportStudentModal(matricula, nombreCompleto, grado, grupo) {
  document.getElementById("report-student-matricula").value = matricula;
  document.getElementById("report-student-name").value = nombreCompleto;
  document.getElementById("report-student-grado").value = grado || "N/A";
  document.getElementById("report-student-grupo").value = grupo || "N/A";
  document.getElementById("report-student-group-display").value = `${grado || "N/A"}° "${grupo || "N/A"}"`;
  
  openModal("modal-report-student");
}

// Hacerlo accesible desde HTML onclick
window.openReportStudentModal = openReportStudentModal;

async function handleReportStudentSubmit(e) {
  e.preventDefault();
  
  const matricula = document.getElementById("report-student-matricula").value;
  const nombre = document.getElementById("report-student-name").value;
  const grado = document.getElementById("report-student-grado").value;
  const grupo = document.getElementById("report-student-grupo").value;
  const motivo = document.getElementById("report-student-reason").value.trim();
  const spinner = document.getElementById("report-student-spinner");
  const errBox = document.getElementById("report-student-error");
  
  if (!motivo) return;
  
  errBox.classList.add("hidden");
  spinner.classList.remove("hidden");
  
  try {
    await db.collection("alertas").add({
      idAlumno: matricula,
      nombreAlumno: nombre,
      grado: grado,
      grupo: grupo,
      idProfesor: currentUser ? currentUser.uid : "N/A",
      nombreProfesor: currentUserDisplayName || "Profesor",
      motivo: motivo,
      fechaHora: firebase.firestore.FieldValue.serverTimestamp(),
      estado: "pendiente",
      tipo: "alumno_con_faltas"
    });
    
    spinner.classList.add("hidden");
    closeAllModals();
    alert("Reporte de alumno enviado con éxito al administrador.");
  } catch (error) {
    console.error("Error al reportar alumno:", error);
    spinner.classList.add("hidden");
    errBox.textContent = "Error al enviar el reporte: " + error.message;
    errBox.classList.remove("hidden");
  }
}

// --- ADMINISTRADOR: Listeners en Tiempo Real y Carga ---
function setupAlertsRealtimeListener() {
  if (alertsListenerUnsubscribe) {
    alertsListenerUnsubscribe();
  }
  
  alertsListenerUnsubscribe = db.collection("alertas")
    .where("estado", "==", "pendiente")
    .onSnapshot((snapshot) => {
      pendingAlerts = [];
      snapshot.forEach((doc) => {
        pendingAlerts.push({
          id: doc.id,
          ...doc.data()
        });
      });
      
      // Ordenar en memoria por fechaHora descendente para evitar requerir index compuesto
      pendingAlerts.sort((a, b) => {
        const tA = a.fechaHora ? (a.fechaHora.toMillis ? a.fechaHora.toMillis() : new Date(a.fechaHora).getTime()) : 0;
        const tB = b.fechaHora ? (b.fechaHora.toMillis ? b.fechaHora.toMillis() : new Date(b.fechaHora).getTime()) : 0;
        return tB - tA;
      });
      
      // Actualizar contador del badge
      const badge = document.getElementById("alerts-count-badge");
      if (badge) {
        if (pendingAlerts.length > 0) {
          badge.textContent = pendingAlerts.length;
          badge.classList.remove("hidden");
        } else {
          badge.classList.add("hidden");
        }
      }
      
      // Refrescar tabla si estamos en la pestaña activa
      const activeTab = document.querySelector(".nav-item.active");
      if (activeTab && activeTab.getAttribute("data-tab") === "admin-alerts") {
        const filterType = document.getElementById("alert-type-filter").value;
        renderAlertsTable(filterType);
      }
    }, (error) => {
      console.error("Error en listener de alertas:", error);
    });
}

function formatFirebaseDate(timestamp) {
  if (!timestamp) return "Sin fecha";
  const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
  return date.toLocaleString('es-MX', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    hour12: true
  });
}

function renderAlertsTable(filterType = "all") {
  const tbody = document.getElementById("alerts-table-body");
  if (!tbody) return;
  
  let filtered = pendingAlerts;
  if (filterType !== "all") {
    filtered = pendingAlerts.filter(a => a.tipo === filterType);
  }
  
  if (filtered.length === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center">No hay alertas pendientes en esta categoría.</td></tr>`;
    return;
  }
  
  tbody.innerHTML = "";
  filtered.forEach((alert) => {
    const tr = document.createElement("tr");
    
    const dateStr = formatFirebaseDate(alert.fechaHora);
    const badgeClass = alert.tipo === "alumno_con_faltas" ? "badge-alumno-faltas" : "badge-profesor-ausente";
    const badgeText = alert.tipo === "alumno_con_faltas" ? "Faltas Alumno" : "Profesor Ausente";
    
    let subjectText = "";
    let reporterText = "";
    
    if (alert.tipo === "alumno_con_faltas") {
      subjectText = `<strong>${alert.nombreAlumno}</strong> (${alert.idAlumno})<br><span style="font-size:0.8rem; color:#64748b;">Grupo: ${alert.grado}° "${alert.grupo}"</span>`;
      reporterText = `${alert.nombreProfesor || "Profesor"}`;
    } else {
      subjectText = `Prof. <strong>${alert.nombreProfesor}</strong><br><span style="font-size:0.8rem; color:#64748b;">Materia: ${alert.materia || "N/A"}</span>`;
      reporterText = `${alert.nombreAlumno} (${alert.idAlumno})`;
    }
    
    tr.innerHTML = `
      <td>${dateStr}</td>
      <td><span class="badge-alert-type ${badgeClass}">${badgeText}</span></td>
      <td>${subjectText}</td>
      <td>${reporterText}</td>
      <td><span class="badge badge-teacher" style="background-color: #fef3c7; color: #d97706; border: 1px solid #fde68a;">${alert.estado}</span></td>
      <td style="text-align: center;">
        <button class="btn btn-primary" onclick="openAlertDetailModal('${alert.id}')" style="padding: 6px 12px; font-size: 0.8rem;">
          Gestionar
        </button>
      </td>
    `;
    tbody.appendChild(tr);
  });
}

async function openAlertDetailModal(alertId) {
  const alertItem = pendingAlerts.find(a => a.id === alertId);
  if (!alertItem) return;
  
  const detailContent = document.getElementById("alert-detail-content");
  const dateStr = formatFirebaseDate(alertItem.fechaHora);
  
  let subjectHtml = "";
  let reporterHtml = "";
  const badgeClass = alertItem.tipo === "alumno_con_faltas" ? "badge-alumno-faltas" : "badge-profesor-ausente";
  const badgeText = alertItem.tipo === "alumno_con_faltas" ? "Alumno con Faltas" : "Profesor Ausente";
  
  if (alertItem.tipo === "alumno_con_faltas") {
    subjectHtml = `
      <div class="alert-detail-grid">
        <div class="alert-detail-item">
          <label>Alumno Reportado</label>
          <span><strong>${alertItem.nombreAlumno}</strong> (Matrícula: ${alertItem.idAlumno})</span>
        </div>
        <div class="alert-detail-item">
          <label>Grado y Grupo</label>
          <span>${alertItem.grado}° "${alertItem.grupo}"</span>
        </div>
      </div>
    `;
    reporterHtml = `
      <div class="alert-detail-item">
        <label>Profesor que Reporta</label>
        <span>${alertItem.nombreProfesor || "Profesor"} (ID: ${alertItem.idProfesor || "N/A"})</span>
      </div>
    `;
  } else {
    subjectHtml = `
      <div class="alert-detail-grid">
        <div class="alert-detail-item">
          <label>Profesor Reportado</label>
          <span><strong>${alertItem.nombreProfesor}</strong></span>
        </div>
        <div class="alert-detail-item">
          <label>Materia</label>
          <span>${alertItem.materia || "N/A"}</span>
        </div>
      </div>
    `;
    reporterHtml = `
      <div class="alert-detail-item">
        <label>Alumno que Reporta</label>
        <span>${alertItem.nombreAlumno} (Matrícula: ${alertItem.idAlumno}, Grupo: ${alertItem.grado}° "${alertItem.grupo}")</span>
      </div>
    `;
  }
  
  detailContent.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
      <span class="badge-alert-type ${badgeClass}">${badgeText}</span>
      <span style="font-size: 0.85rem; color: #64748b;"><strong>Fecha del Reporte:</strong> ${dateStr}</span>
    </div>
    
    <h4>Sujeto de la Alerta</h4>
    ${subjectHtml}
    
    <h4 style="margin-top: 15px;">Origen del Reporte</h4>
    <div class="alert-detail-grid">
      ${reporterHtml}
    </div>
    
    <h4 style="margin-top: 15px;">Motivo / Descripción</h4>
    <div class="alert-detail-reason">
      ${alertItem.motivo}
    </div>
  `;
  
  openModal("modal-alert-detail");
  checkTutorLinkage(alertItem);
}

window.openAlertDetailModal = openAlertDetailModal;

async function checkTutorLinkage(alertItem) {
  const infoDiv = document.getElementById("alert-tutor-linking-info");
  const messageSection = document.getElementById("alert-tutor-message-section");
  const btnResolve = document.getElementById("btn-mark-alert-resolved");
  
  btnResolve.setAttribute("data-alert-id", alertItem.id);
  
  if (alertItem.tipo !== "alumno_con_faltas") {
    infoDiv.innerHTML = `
      <div class="tutor-link-status unlinked">
        <i class="material-icons" style="font-size:18px;">info</i>
        <span>No se requiere notificar al tutor para reportes de ausencia de docentes.</span>
      </div>
    `;
    messageSection.classList.add("hidden");
    return;
  }
  
  infoDiv.innerHTML = `
    <div style="display: flex; align-items: center; gap: 8px; color: var(--color-primary);">
      <div class="spinner" style="border-top-color: var(--color-primary); width:16px; height:16px;"></div>
      <span>Buscando vinculación de tutor en base de datos...</span>
    </div>
  `;
  messageSection.classList.add("hidden");
  
  try {
    const studentDoc = await db.collection("zktime_empleados").doc(alertItem.idAlumno).get();
    
    if (!studentDoc.exists) {
      infoDiv.innerHTML = `
        <div class="tutor-link-status unlinked">
          <i class="material-icons" style="font-size:18px; color: var(--color-danger);">warning</i>
          <span>El alumno no existe en el catálogo biométrico del plantel.</span>
        </div>
      `;
      return;
    }
    
    const studentData = studentDoc.data();
    const padreId = studentData.padreId;
    
    if (!padreId) {
      infoDiv.innerHTML = `
        <div class="tutor-link-status unlinked">
          <i class="material-icons" style="font-size:18px; color: #64748b;">warning</i>
          <span>Este alumno no cuenta con un tutor/padre de familia vinculado en la app móvil.</span>
        </div>
      `;
      return;
    }
    
    const tutorDoc = await db.collection("usuarios").doc(padreId).get();
    
    if (!tutorDoc.exists) {
      infoDiv.innerHTML = `
        <div class="tutor-link-status unlinked">
          <i class="material-icons" style="font-size:18px; color: var(--color-warning);">warning</i>
          <span>Tutor vinculado con UID: <code>${padreId}</code>, pero el perfil del usuario no existe.</span>
        </div>
      `;
      return;
    }
    
    const tutorData = tutorDoc.data();
    const tutorName = tutorData.nombre || "Tutor sin Nombre";
    const tutorEmail = tutorData.email || "Sin Correo";
    
    infoDiv.innerHTML = `
      <div class="tutor-link-status linked">
        <i class="material-icons" style="font-size:20px; color: var(--color-success);">check_circle</i>
        <span><strong>Tutor Vinculado:</strong> ${tutorName} (${tutorEmail})</span>
      </div>
    `;
    
    // Rellenar formulario de mensaje al tutor
    document.getElementById("message-tutor-id").value = padreId;
    document.getElementById("message-tutor-name").value = tutorName;
    document.getElementById("message-student-id").value = alertItem.idAlumno;
    document.getElementById("message-student-name").value = alertItem.nombreAlumno;
    document.getElementById("message-alert-id").value = alertItem.id;
    
    document.getElementById("message-tutor-text").value = `Estimado(a) tutor(a) ${tutorName}, se le notifica que su hijo(a) ${alertItem.nombreAlumno} del grupo ${alertItem.grado}° "${alertItem.grupo}" ha registrado inasistencias a clases reportadas por su docente. Motivo reportado: "${alertItem.motivo}". Agradecemos su atención para revisar esta situación con el alumno.`;
    
    messageSection.classList.remove("hidden");
  } catch (error) {
    console.error("Error al buscar tutor:", error);
    infoDiv.innerHTML = `
      <div class="tutor-link-status unlinked">
        <i class="material-icons" style="font-size:18px; color: var(--color-danger);">error</i>
        <span>Error de conexión al verificar el estado de vinculación del tutor.</span>
      </div>
    `;
  }
}

async function handleSendTutorMessage(e) {
  e.preventDefault();
  
  const alertId = document.getElementById("message-alert-id").value;
  const idTutor = document.getElementById("message-tutor-id").value;
  const nombreTutor = document.getElementById("message-tutor-name").value;
  const idAlumno = document.getElementById("message-student-id").value;
  const nombreAlumno = document.getElementById("message-student-name").value;
  const mensajeText = document.getElementById("message-tutor-text").value.trim();
  
  const spinner = document.getElementById("send-message-spinner");
  const errBox = document.getElementById("send-message-error");
  
  if (!mensajeText) return;
  
  errBox.classList.add("hidden");
  spinner.classList.remove("hidden");
  
  try {
    const batch = db.batch();
    
    // 1. Guardar en mensajes_tutores
    const msgRef = db.collection("mensajes_tutores").doc();
    batch.set(msgRef, {
      idTutor: idTutor,
      nombreTutor: nombreTutor,
      idAlumno: idAlumno,
      nombreAlumno: nombreAlumno,
      mensaje: mensajeText,
      fechaHora: firebase.firestore.FieldValue.serverTimestamp(),
      enviadoPor: "admin",
      leido: false
    });
    
    // 2. Marcar alerta como atendida
    const alertRef = db.collection("alertas").doc(alertId);
    batch.update(alertRef, {
      estado: "atendida"
    });
    
    await batch.commit();
    
    spinner.classList.add("hidden");
    closeAllModals();
    alert("Mensaje enviado con éxito al tutor. La alerta ha sido marcada como atendida.");
  } catch (error) {
    console.error("Error al enviar mensaje al tutor:", error);
    spinner.classList.add("hidden");
    errBox.textContent = "Error al enviar: " + error.message;
    errBox.classList.remove("hidden");
  }
}

async function handleMarkAlertAtendida() {
  const alertId = this.getAttribute("data-alert-id");
  if (!alertId) return;
  
  if (!confirm("¿Estás seguro de marcar esta alerta como atendida sin enviar mensaje al tutor?")) {
    return;
  }
  
  try {
    await db.collection("alertas").doc(alertId).update({
      estado: "atendida"
    });
    
    closeAllModals();
    alert("La alerta ha sido marcada como atendida.");
  } catch (error) {
    console.error("Error al resolver alerta:", error);
    alert("Error al actualizar el estado de la alerta: " + error.message);
  }
}

// ==========================================================================
// 9. REPORTE Y CONSULTA DE ASISTENCIAS MB160 (ADMIN & MAESTRO)
// ==========================================================================

async function loadAdminMb160Attendance() {
  const tbody = document.getElementById("mb160-attendance-tbody");
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="6" class="text-center">Cargando marcaciones...</td></tr>';
  
  const dateVal = document.getElementById("mb160-filter-date").value || getTodayLocalDate();
  const groupVal = document.getElementById("mb160-filter-group").value;
  
  try {
    const snapshot = await db.collection("asistencias")
      .where("fecha", "==", dateVal)
      .get();
      
    if (snapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay registros de asistencias para esta fecha.</td></tr>';
      return;
    }
    
    // Mapear alumnos para filtrar en memoria por grupo y obtener su información
    const studentMap = {};
    allStudents.forEach(s => {
      studentMap[s.matricula] = s;
    });
    
    const records = [];
    snapshot.forEach(doc => {
      records.push(doc.data());
    });
    
    // Ordenar por fechaHora desc
    records.sort((a, b) => b.fechaHora.localeCompare(a.fechaHora));
    
    tbody.innerHTML = "";
    let renderedCount = 0;
    
    records.forEach(r => {
      const student = studentMap[r.matricula];
      const studentGradoGrupo = student ? student.gradoGrupo : (r.grado && r.grupo ? `${r.grado}${r.grupo}` : "N/A");
      
      // Filtrar por grupo si se seleccionó uno
      if (groupVal && studentGradoGrupo !== groupVal) {
        return;
      }
      
      renderedCount++;
      const tr = document.createElement("tr");
      
      // Formatear tipo de registro
      const tipo = r.tipoRegistro || "entrada";
      const tipoBadge = tipo === "entrada"
        ? `<span class="badge" style="background-color:rgba(16,185,129,0.1); color:var(--color-success)">Entrada</span>`
        : `<span class="badge" style="background-color:rgba(245,158,11,0.1); color:var(--color-warning)">Salida</span>`;
        
      tr.innerHTML = `
        <td><strong>${formatDateToShow(r.fecha)} ${r.hora || ""}</strong></td>
        <td>${r.matricula}</td>
        <td><strong>${r.nombreAlumno || r.nombre}</strong></td>
        <td><span class="badge badge-teacher">${studentGradoGrupo}</span></td>
        <td>${tipoBadge}</td>
        <td style="color:#64748b; font-size:0.8rem;">${r.origen || "MB160"}</td>
      `;
      tbody.appendChild(tr);
    });
    
    if (renderedCount === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center">No hay registros de asistencia para el grupo seleccionado en esta fecha.</td></tr>';
    }
  } catch (error) {
    console.error("Error al cargar asistencias admin MB160:", error);
    tbody.innerHTML = '<tr><td colspan="6" class="text-center error-message">Error al consultar base de datos.</td></tr>';
  }
}

async function loadTeacherMb160Attendance() {
  const tbody = document.getElementById("teacher-mb160-tbody");
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="5" class="text-center">Cargando marcaciones...</td></tr>';
  
  if (!activeClass) return;
  const fecha = document.getElementById("attendance-date").value || getTodayLocalDate();
  
  try {
    // 1. Obtener alumnos en este salón
    const studentSnapshot = await db.collection("zktime_empleados").where("gradoGrupo", "==", activeClass.gradoGrupo).get();
    
    if (studentSnapshot.empty) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center">No hay alumnos asignados a este grupo.</td></tr>';
      return;
    }
    
    const studentMatriculas = new Set();
    const studentMap = {};
    studentSnapshot.forEach(doc => {
      const data = doc.data();
      studentMatriculas.add(data.matricula);
      studentMap[data.matricula] = data.nombreCompleto || `${data.nombre} ${data.apellidos}`;
    });
    
    // 2. Obtener asistencias para este día
    const snapshot = await db.collection("asistencias")
      .where("fecha", "==", fecha)
      .get();
      
    const records = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      if (studentMatriculas.has(data.matricula)) {
        records.push(data);
      }
    });
    
    // Ordenar por fechaHora desc
    records.sort((a, b) => b.fechaHora.localeCompare(a.fechaHora));
    
    tbody.innerHTML = "";
    if (records.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="text-center">No hay marcaciones biométricas registradas para este grupo en esta fecha.</td></tr>';
      return;
    }
    
    records.forEach(r => {
      const tr = document.createElement("tr");
      const tipo = r.tipoRegistro || "entrada";
      const tipoBadge = tipo === "entrada"
        ? `<span class="badge" style="background-color:rgba(16,185,129,0.1); color:var(--color-success)">Entrada</span>`
        : `<span class="badge" style="background-color:rgba(245,158,11,0.1); color:var(--color-warning)">Salida</span>`;
        
      tr.innerHTML = `
        <td><strong>${formatDateToShow(r.fecha)} ${r.hora || ""}</strong></td>
        <td>${r.matricula}</td>
        <td><strong>${studentMap[r.matricula] || r.nombre}</strong></td>
        <td>${tipoBadge}</td>
        <td style="color:#64748b; font-size:0.8rem;">${r.origen || "MB160"}</td>
      `;
      tbody.appendChild(tr);
    });
  } catch (error) {
    console.error("Error al cargar asistencias teacher MB160:", error);
    tbody.innerHTML = '<tr><td colspan="5" class="text-center error-message">Error al cargar marcaciones.</td></tr>';
  }
}

// Exponer funciones globalmente
window.loadAdminMb160Attendance = loadAdminMb160Attendance;
window.loadTeacherMb160Attendance = loadTeacherMb160Attendance;
