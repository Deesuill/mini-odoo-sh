"use strict";

const API_URL = "/api/instances";
const REFRESH_INTERVAL_MS = 15000;

const instancesGrid = document.getElementById("instances-grid");
const emptyState = document.getElementById("empty-state");
const message = document.getElementById("message");
const refreshButton = document.getElementById("refresh-button");
const lastUpdated = document.getElementById("last-updated");
const cardTemplate = document.getElementById(
    "instance-card-template"
);

const instanceCount = document.getElementById("instance-count");
const runningCount = document.getElementById("running-count");
const stoppedCount = document.getElementById("stopped-count");
const problemCount = document.getElementById("problem-count");

let refreshInProgress = false;


function normalizeStatus(status) {
    const normalized = String(status || "unknown")
        .trim()
        .toLowerCase();

    const supportedStatuses = new Set([
        "running",
        "stopped",
        "partial",
        "restarting",
        "paused",
        "error",
        "unavailable",
        "missing",
        "unknown",
    ]);

    if (supportedStatuses.has(normalized)) {
        return normalized;
    }

    return "unknown";
}


function setStatusClass(element, status) {
    const normalizedStatus = normalizeStatus(status);

    element.className = element.className
        .split(" ")
        .filter((className) => {
            return !className.startsWith("status-");
        })
        .join(" ");

    element.classList.add(`status-${normalizedStatus}`);
    element.textContent = normalizedStatus;
}


function formatBoolean(value) {
    return value ? "Yes" : "No";
}


function formatHttpStatus(instance) {
    const http = instance.http;

    if (!http || typeof http !== "object") {
        return "Unavailable";
    }

    if (http.reachable) {
        if (http.status_code) {
            return `Reachable (${http.status_code})`;
        }

        return "Reachable";
    }

    return "Unreachable";
}

async function runInstanceAction(
    instanceName,
    action,
    card
) {
    const buttons = Array.from(
        card.querySelectorAll(".action-button")
    );

    const originalDisabledStates = buttons.map(
        (button) => button.disabled
    );

    buttons.forEach((button) => {
        button.disabled = true;
    });

    const errorElement = card.querySelector(
        ".instance-error"
    );

    errorElement.textContent = "";
    errorElement.classList.add("hidden");

    try {
        const response = await fetch(
            `/api/instances/${encodeURIComponent(
                instanceName
            )}/actions`,
            {
                method: "POST",
                headers: {
                    "Content-Type": "application/json",
                    Accept: "application/json",
                },
                body: JSON.stringify({
                    action,
                }),
            }
        );

        let payload;

        try {
            payload = await response.json();
        } catch {
            throw new Error(
                "The API returned an invalid response."
            );
        }

        if (!response.ok) {
            const details = payload.details
                ? `: ${payload.details}`
                : "";

            throw new Error(
                `${payload.error || "Action failed"}${details}`
            );
        }

        await loadInstances();
    } catch (error) {
        console.error(error);

        errorElement.textContent =
            error instanceof Error
                ? error.message
                : "Instance action failed.";

        errorElement.classList.remove("hidden");
    } finally {
        buttons.forEach((button, index) => {
            button.disabled =
                originalDisabledStates[index];
        });
    }
}

function createServiceBadge(serviceName, serviceStatus) {
    const badge = document.createElement("span");
    badge.className = "service-badge";

    setStatusClass(badge, serviceStatus);

    badge.textContent = "";

    const nameElement = document.createElement("span");
    nameElement.className = "service-name";
    nameElement.textContent = serviceName;

    const statusElement = document.createElement("span");
    statusElement.textContent = normalizeStatus(serviceStatus);

    badge.append(nameElement, statusElement);

    return badge;
}


function renderServices(container, services) {
    container.replaceChildren();

    if (
        !services ||
        typeof services !== "object" ||
        Object.keys(services).length === 0
    ) {
        const unavailable = document.createElement("span");
        unavailable.className =
            "service-badge status-unknown";
        unavailable.textContent = "No service data";

        container.appendChild(unavailable);
        return;
    }

    Object.entries(services)
        .sort(([firstName], [secondName]) => {
            return firstName.localeCompare(secondName);
        })
        .forEach(([serviceName, serviceStatus]) => {
            container.appendChild(
                createServiceBadge(
                    serviceName,
                    serviceStatus
                )
            );
        });
}


function renderInstanceCard(instance) {
    const fragment = cardTemplate.content.cloneNode(true);

    const name = fragment.querySelector(".instance-name");
    const status = fragment.querySelector(".status-badge");
    const repository = fragment.querySelector(
        ".instance-repository"
    );
    const port = fragment.querySelector(".instance-port");
    const registered = fragment.querySelector(
        ".instance-registered"
    );
    const http = fragment.querySelector(".instance-http");
    const services = fragment.querySelector(".services-list");
    const odooLink = fragment.querySelector(".odoo-link");
    const error = fragment.querySelector(".instance-error");
    const card = fragment.querySelector(
        ".instance-card"
    );

    const actionButtons = fragment.querySelectorAll(
        ".action-button"
    );

    const normalizedInstanceStatus =
        normalizeStatus(instance.status);

    const startButton = fragment.querySelector(
        ".start-button"
    );

    const restartButton = fragment.querySelector(
        ".restart-button"
    );

    const stopButton = fragment.querySelector(
        ".stop-button"
    );

    if (normalizedInstanceStatus === "running") {
        startButton.disabled = true;
    }

    if (normalizedInstanceStatus === "stopped") {
        stopButton.disabled = true;
        restartButton.disabled = true;
    }

    if (
        normalizedInstanceStatus === "missing" ||
        normalizedInstanceStatus === "unavailable" ||
        normalizedInstanceStatus === "error"
    ) {
        actionButtons.forEach((button) => {
            button.disabled = true;
        });
    }

    name.textContent = instance.name || "Unknown instance";
    setStatusClass(status, instance.status);

    repository.textContent =
        instance.repository || "Not configured";

    port.textContent =
        instance.port === null ||
        instance.port === undefined
            ? "Not configured"
            : String(instance.port);

    registered.textContent = formatBoolean(
        Boolean(instance.registered)
    );

    http.textContent = formatHttpStatus(instance);

    renderServices(services, instance.services);

    if (
        instance.http &&
        instance.http.reachable &&
        instance.http.url
    ) {
        odooLink.href = instance.http.url;
        odooLink.classList.remove("hidden");
    }

    if (instance.error) {
        const errorDetails = instance.details
            ? `${instance.error}: ${instance.details}`
            : instance.error;

        error.textContent = errorDetails;
        error.classList.remove("hidden");
    }

    actionButtons.forEach((button) => {
        button.addEventListener("click", async () => {
            const action = button.dataset.action;

            if (!action) {
                return;
            }

            if (
                action === "stop" &&
                !window.confirm(
                    `Stop instance "${instance.name}"?`
                )
            ) {
                return;
            }

            if (
                action === "restart" &&
                !window.confirm(
                    `Restart instance "${instance.name}"?`
                )
            ) {
                return;
            }

            await runInstanceAction(
                instance.name,
                action,
                card
            );
        });
    });

    return fragment;
}


function updateSummary(instances) {
    const statusTotals = instances.reduce(
        (totals, instance) => {
            const status = normalizeStatus(instance.status);

            if (status === "running") {
                totals.running += 1;
            } else if (status === "stopped") {
                totals.stopped += 1;
            } else {
                totals.problems += 1;
            }

            return totals;
        },
        {
            running: 0,
            stopped: 0,
            problems: 0,
        }
    );

    instanceCount.textContent = String(instances.length);
    runningCount.textContent = String(statusTotals.running);
    stoppedCount.textContent = String(statusTotals.stopped);
    problemCount.textContent = String(statusTotals.problems);
}


function renderInstances(instances) {
    instancesGrid.replaceChildren();
    updateSummary(instances);

    if (instances.length === 0) {
        emptyState.classList.remove("hidden");
        return;
    }

    emptyState.classList.add("hidden");

    instances.forEach((instance) => {
        instancesGrid.appendChild(
            renderInstanceCard(instance)
        );
    });
}


function showError(errorText) {
    message.textContent = errorText;
    message.className = "message message-error";
}


function hideMessage() {
    message.textContent = "";
    message.className = "message hidden";
}


async function loadInstances() {
    if (refreshInProgress) {
        return;
    }

    refreshInProgress = true;
    refreshButton.disabled = true;
    refreshButton.textContent = "Refreshing...";

    try {
        const response = await fetch(API_URL, {
            method: "GET",
            headers: {
                Accept: "application/json",
            },
            cache: "no-store",
        });

        let payload;

        try {
            payload = await response.json();
        } catch {
            throw new Error(
                "The API returned an invalid response."
            );
        }

        if (!response.ok) {
            throw new Error(
                payload.error ||
                `API request failed with status ${response.status}.`
            );
        }

        const instances = Array.isArray(payload.instances)
            ? payload.instances
            : [];

        renderInstances(instances);
        hideMessage();

        lastUpdated.textContent =
            `Updated ${new Date().toLocaleTimeString()}`;
    } catch (error) {
        console.error(error);

        showError(
            error instanceof Error
                ? error.message
                : "Could not load instances."
        );
    } finally {
        refreshInProgress = false;
        refreshButton.disabled = false;
        refreshButton.textContent = "Refresh";
    }
}


refreshButton.addEventListener("click", loadInstances);

loadInstances();

window.setInterval(
    loadInstances,
    REFRESH_INTERVAL_MS
);
