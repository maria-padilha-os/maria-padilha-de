// Pure index arithmetic shared by the Nexus page list and setting rows. Keeping
// it here lets the focus transitions be tested without instantiating services.

function clamp(index, count) {
    if (count <= 0)
        return -1;
    return Math.max(0, Math.min(count - 1, index));
}

function step(index, count, delta) {
    if (count <= 0)
        return -1;
    if (index < 0)
        return delta > 0 ? 0 : count - 1;
    return clamp(index + delta, count);
}

function stepInList(list, current, delta) {
    if (!list || list.length === 0)
        return -1;

    let index = list.indexOf(current);
    if (index < 0)
        index = delta > 0 ? -1 : list.length;

    return step(index, list.length, delta);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        clamp: clamp,
        step: step,
        stepInList: stepInList
    };
}
