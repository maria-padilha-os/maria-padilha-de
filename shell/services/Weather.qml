pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.utils
import "WeatherData.js" as WeatherData

Singleton {
    id: root

    property string city
    property string countryCode: ""
    property string loc
    property var cc: null
    property list<var> forecast: []
    property list<var> hourlyForecast: []

    // "idle", "no-location", "loading", "ready", "stale" or "error".
    property string status: "idle"
    property string errorMessage: ""
    property double lastUpdated: 0
    property double now: Date.now()
    property bool fromCache: false

    property bool configLoaded: false
    property bool cacheLoaded: false
    property string cacheText: ""
    property var fileConfig: ({})

    property bool requestPending: false
    property bool geocodePending: false
    property int requestToken: 0

    property bool searchPending: false
    property string searchMessage: ""
    property var searchResults: []
    property double searchBlockedUntil: 0
    property int searchToken: 0

    readonly property string savedLocation: WeatherData.normaliseString(GlobalConfig.services.weatherLocation)
    readonly property string savedCoordinates: WeatherData.normaliseString(GlobalConfig.services.weatherCoordinates)

    readonly property string configPath: WeatherData.configPath(Quickshell.env("HOME") || "", Quickshell.env("XDG_CONFIG_HOME") || "")
    readonly property string providerUrl: {
        const env = WeatherData.normaliseString(Quickshell.env("PADILHA_WEATHER_PROVIDER_URL") || "");
        if (env.length > 0)
            return env;
        const file = WeatherData.normaliseString(root.fileConfig.providerUrl);
        if (file.length > 0)
            return file;
        return WeatherData.normaliseString(GlobalConfig.services.weatherProviderUrl) || WeatherData.DEFAULT_PROVIDER_URL;
    }
    readonly property string apiKey: {
        const env = WeatherData.normaliseString(Quickshell.env("PADILHA_WEATHER_API_KEY") || "");
        if (env.length > 0)
            return env;
        const file = WeatherData.normaliseString(root.fileConfig.apiKey);
        if (file.length > 0)
            return file;
        return WeatherData.normaliseString(GlobalConfig.services.weatherApiKey);
    }
    readonly property string geocodingUrl: {
        const env = WeatherData.normaliseString(Quickshell.env("PADILHA_WEATHER_GEOCODING_URL") || "");
        if (env.length > 0)
            return env;
        const file = WeatherData.normaliseString(root.fileConfig.geocodingUrl);
        if (file.length > 0)
            return file;
        return WeatherData.normaliseString(GlobalConfig.services.weatherGeocodingUrl) || WeatherData.DEFAULT_GEOCODING_URL;
    }
    readonly property string language: {
        const env = WeatherData.normaliseString(Quickshell.env("PADILHA_WEATHER_LANGUAGE") || "");
        if (env.length > 0)
            return env;
        const file = WeatherData.normaliseString(root.fileConfig.language);
        if (file.length > 0)
            return file;
        const configured = WeatherData.normaliseString(GlobalConfig.services.weatherLanguage);
        if (configured.length > 0)
            return configured;
        const locale = String(Qt.locale().name).split("_")[0] || "en";
        return locale === "C" ? "en" : locale;
    }
    readonly property int refreshSeconds: WeatherData.refreshSeconds(
        WeatherData.normaliseString(root.fileConfig.refreshInterval).length > 0
            ? root.fileConfig.refreshInterval
            : GlobalConfig.services.weatherRefreshInterval
    )
    readonly property int cacheTtlSeconds: WeatherData.cacheTtlSeconds(
        WeatherData.normaliseString(root.fileConfig.cacheTtl).length > 0
            ? root.fileConfig.cacheTtl
            : GlobalConfig.services.weatherCacheTtl
    )

    readonly property bool hasData: cc !== null && cc !== undefined
    readonly property bool isStale: hasData && lastUpdated > 0 && (now - lastUpdated) > cacheTtlSeconds * 1000

    readonly property string icon: hasData ? Icons.getWeatherIcon(cc.weatherCode) : "cloud_alert"
    readonly property string description: {
        if (hasData)
            return getWeatherCondition(cc.weatherCode);
        if (status === "no-location")
            return Tr.tr("No weather location");
        if (status === "error")
            return Tr.tr("Weather unavailable");
        return Tr.tr("No weather");
    }
    readonly property string temp: formatTemp(cc?.tempC)
    readonly property string feelsLike: formatTemp(cc?.feelsLikeC)
    readonly property int humidity: cc?.humidity ?? 0
    readonly property real windSpeed: cc?.windSpeed ?? 0
    readonly property string sunrise: cc ? Qt.formatDateTime(new Date(cc.sunrise), Units.twelveHourClock ? "h:mm A" : "h:mm") : "--:--"
    readonly property string sunset: cc ? Qt.formatDateTime(new Date(cc.sunset), Units.twelveHourClock ? "h:mm A" : "h:mm") : "--:--"

    readonly property string lastUpdatedLabel: {
        if (!hasData || lastUpdated <= 0)
            return "";
        const date = new Date(lastUpdated);
        const current = new Date(now);
        const sameDay = date.toDateString() === current.toDateString();
        const time = Qt.formatDateTime(date, Units.twelveHourClock ? "h:mm AP" : "HH:mm");
        return sameDay
            ? Tr.tr("Last updated %1").arg(time)
            : Tr.tr("Last updated %1").arg(Qt.formatDateTime(date, "MMM d, " + (Units.twelveHourClock ? "h:mm AP" : "HH:mm")));
    }
    readonly property string statusText: {
        if (status === "no-location")
            return Tr.tr("No weather location set");
        if (status === "loading" && !hasData)
            return Tr.tr("Loading weather…");
        if (status === "error")
            return errorMessage || Tr.tr("Weather unavailable");
        if (status === "stale")
            return errorMessage
                ? Tr.tr("%1 · showing the last saved weather").arg(errorMessage)
                : Tr.tr("Showing the last saved weather");
        return "";
    }
    readonly property bool canRetry: status === "error" || status === "stale" || isStale

    function formatTemp(temp: var, compact = false): string {
        let unit = GlobalConfig.services.weatherUnits;
        // Auto follows the weather location, not the UI language. Otherwise an
        // English UI in Brazil would report Fahrenheit.
        if (Number(unit) === TemperatureUnit.Auto && root.countryCode.length > 0)
            unit = Units.temperatureUnitForCountry(root.countryCode);
        const value = temp !== undefined && temp !== null ? Math.round(Units.toTemperature(temp, unit)) : "--";
        return Units.formatTemp(value, unit, compact);
    }

    function reload(): void {
        if (!root.configLoaded || !root.cacheLoaded)
            return;

        const location = root.savedLocation;
        if (location.length === 0) {
            root.resetWeather("no-location", "");
            return;
        }

        const configuredCoords = WeatherData.coordinatesOf(root.savedCoordinates) || WeatherData.coordinatesOf(location);
        const cached = WeatherData.readCache(root.cacheText);
        const matches = cached && WeatherData.cacheMatches(cached, {
            providerUrl: root.providerUrl,
            location: location,
            coordinates: configuredCoords
        });
        const cachedCoords = cached ? WeatherData.coordinatesOf(cached.coordinates) : null;

        if (matches && root.applyCache(cached)) {
            if (WeatherData.isCacheFresh(cached, root.cacheTtlSeconds, Date.now())) {
                root.status = root.isStale ? "stale" : "ready";
                root.errorMessage = "";
                return;
            }
            // Stale cache stays on screen while the refresh runs. The timer is
            // bounded, so a failed provider is retried once per interval.
            if (configuredCoords || cachedCoords)
                root.fetchForecast(configuredCoords || cachedCoords, location, root.city, root.countryCode);
            else
                root.geocodeLocation(location);
            return;
        }

        if (configuredCoords) {
            root.clearWeatherData();
            root.status = "loading";
            root.city = location;
            root.fetchForecast(configuredCoords, location, root.city, root.countryCode);
            return;
        }

        root.clearWeatherData();
        root.status = "loading";
        root.geocodeLocation(location);
    }

    // Forced refresh used by the refresh timer and the retry action. It never
    // runs more often than refreshSeconds, because only one timer calls it.
    function refresh(): void {
        if (!root.configLoaded)
            return;

        const location = root.savedLocation;
        if (location.length === 0) {
            root.resetWeather("no-location", "");
            return;
        }

        const configuredCoords = WeatherData.coordinatesOf(root.savedCoordinates) || WeatherData.coordinatesOf(location);
        if (configuredCoords) {
            root.fetchForecast(configuredCoords, location, root.city || location, root.countryCode);
            return;
        }

        const cached = WeatherData.readCache(root.cacheText);
        if (cached && WeatherData.cacheMatches(cached, { providerUrl: root.providerUrl, location: location })) {
            const cachedCoords = WeatherData.coordinatesOf(cached.coordinates);
            if (cachedCoords) {
                root.fetchForecast(cachedCoords, location, root.city || cached.city || location, root.countryCode || cached.countryCode);
                return;
            }
        }

        root.geocodeLocation(location);
    }

    function setLocation(value: string): void {
        const text = WeatherData.normaliseString(value);
        GlobalConfig.services.weatherCoordinates = "";
        GlobalConfig.services.weatherLocation = text;
        root.settingsChanged();
    }

    function saveLocation(result: var): void {
        if (!result)
            return;
        root.city = WeatherData.normaliseString(result.name);
        root.countryCode = WeatherData.normaliseString(result.countryCode);
        GlobalConfig.services.weatherCoordinates = WeatherData.formatCoordinates(result);
        GlobalConfig.services.weatherLocation = WeatherData.normaliseString(result.label) || WeatherData.normaliseString(result.displayName) || root.city;
        root.searchResults = [];
        root.searchMessage = "";
        root.settingsChanged();
    }

    function clearLocation(): void {
        root.invalidateRequests();
        GlobalConfig.services.weatherCoordinates = "";
        GlobalConfig.services.weatherLocation = "";
        root.cacheText = "";
        weatherCache.setText("{}");
        root.searchResults = [];
        root.searchMessage = "";
        root.resetWeather("no-location", "");
    }

    function searchLocations(query: string): void {
        const text = WeatherData.normaliseString(query);
        root.searchResults = [];
        root.searchMessage = "";

        if (text.length === 0) {
            root.searchMessage = Tr.tr("Enter a city or place");
            return;
        }
        if (root.searchPending)
            return;
        if (Date.now() < root.searchBlockedUntil) {
            root.searchMessage = Tr.tr("Please wait a moment before searching again");
            return;
        }

        const url = WeatherData.buildGeocodingUrl({
            geocodingUrl: root.geocodingUrl,
            query: text,
            language: root.language,
            count: WeatherData.MAX_GEOCODING_RESULTS
        });
        if (url.length === 0) {
            root.searchMessage = Tr.tr("Weather search URL is invalid");
            return;
        }

        const token = ++root.searchToken;
        root.searchPending = true;
        Requests.get(url, (response, metadata) => {
            if (token !== root.searchToken)
                return;
            root.searchPending = false;
            root.searchBlockedUntil = Date.now() + 1100;

            let results;
            try {
                results = WeatherData.parseGeocodingResponse(response);
            } catch (error) {
                root.searchMessage = Tr.tr("Could not read the place search results");
                return;
            }

            if (results.length === 0) {
                root.searchMessage = Tr.tr("No places found for “%1”").arg(text);
                return;
            }
            root.searchResults = results;
        }, (error, metadata) => {
            if (token !== root.searchToken)
                return;
            root.searchPending = false;
            root.searchBlockedUntil = Date.now() + 1100;
            root.searchMessage = root.describeError(error, metadata);
        });
    }

    function applyCache(record: var): bool {
        try {
            const parsed = WeatherData.parseWeatherResponse(record.payload, { now: Date.now() });
            root.cc = parsed.cc;
            root.forecast = parsed.forecast;
            root.hourlyForecast = parsed.hourlyForecast;
            root.lastUpdated = Number(record.updatedAt);
            root.city = WeatherData.normaliseString(record.city) || WeatherData.normaliseString(record.location);
            root.countryCode = WeatherData.normaliseString(record.countryCode);
            root.loc = WeatherData.normaliseString(record.coordinates);
            root.fromCache = true;
            root.now = Date.now();
            return true;
        } catch (error) {
            console.warn(lc, `Unable to read the weather cache: ${error}`);
            return false;
        }
    }

    function applyParsed(parsed: var, updatedAt: double, cityName: string, country: string): void {
        root.cc = parsed.cc;
        root.forecast = parsed.forecast;
        root.hourlyForecast = parsed.hourlyForecast;
        root.lastUpdated = updatedAt;
        root.city = WeatherData.normaliseString(cityName) || root.city;
        root.countryCode = WeatherData.normaliseString(country) || root.countryCode;
        root.fromCache = false;
        root.now = Date.now();
    }

    function fetchForecast(coords: var, location: string, cityName: string, country: string): void {
        if (root.requestPending)
            return;

        const pair = WeatherData.coordinatesOf(coords);
        if (!pair) {
            root.failWeather(Tr.tr("The saved weather location is invalid"));
            return;
        }

        const url = WeatherData.buildWeatherUrl({
            providerUrl: root.providerUrl,
            apiKey: root.apiKey,
            language: root.language,
            latitude: pair.latitude,
            longitude: pair.longitude
        });
        if (url.length === 0) {
            root.failWeather(Tr.tr("The weather provider URL is invalid"));
            return;
        }

        const token = ++root.requestToken;
        root.requestPending = true;
        root.errorMessage = "";
        if (!root.hasData)
            root.status = "loading";

        const headers = {};
        if (root.apiKey.length > 0)
            headers["X-API-Key"] = root.apiKey;

        Requests.get(url, (response, metadata) => {
            if (token !== root.requestToken)
                return;
            root.requestPending = false;

            let payload;
            try {
                payload = JSON.parse(response);
            } catch (error) {
                root.failWeather(Tr.tr("The weather provider returned an unreadable response"));
                return;
            }

            let parsed;
            try {
                parsed = WeatherData.parseWeatherResponse(payload);
            } catch (error) {
                console.warn(lc, `Unexpected weather response: ${error}`);
                root.failWeather(Tr.tr("The weather provider returned an unexpected response"));
                return;
            }

            const updatedAt = Date.now();
            root.applyParsed(parsed, updatedAt, cityName, country);
            root.loc = WeatherData.formatCoordinates(pair);
            root.status = "ready";
            root.errorMessage = "";
            root.saveCache(payload, location, pair, root.city, root.countryCode, updatedAt);
        }, (error, metadata) => {
            if (token !== root.requestToken)
                return;
            root.requestPending = false;
            root.failWeather(root.describeError(error, metadata));
        }, headers);
    }

    function geocodeLocation(location: string): void {
        if (root.geocodePending)
            return;

        const url = WeatherData.buildGeocodingUrl({
            geocodingUrl: root.geocodingUrl,
            query: location,
            language: root.language,
            count: 1
        });
        if (url.length === 0) {
            root.failWeather(Tr.tr("The weather search URL is invalid"));
            return;
        }

        const token = ++root.requestToken;
        root.geocodePending = true;
        root.errorMessage = "";
        if (!root.hasData)
            root.status = "loading";

        Requests.get(url, (response, metadata) => {
            if (token !== root.requestToken)
                return;
            root.geocodePending = false;

            let results;
            try {
                results = WeatherData.parseGeocodingResponse(response, { count: 1 });
            } catch (error) {
                root.failWeather(Tr.tr("Could not read the place search result"));
                return;
            }

            if (results.length === 0) {
                root.failWeather(Tr.tr("No place found for “%1”. Try a more specific name.").arg(location));
                return;
            }

            const result = results[0];
            root.city = result.name;
            root.countryCode = result.countryCode;
            root.loc = WeatherData.formatCoordinates(result);
            root.fetchForecast(result, location, result.name, result.countryCode);
        }, (error, metadata) => {
            if (token !== root.requestToken)
                return;
            root.geocodePending = false;
            root.failWeather(root.describeError(error, metadata));
        });
    }

    function saveCache(payload: var, location: string, coords: var, cityName: string, country: string, updatedAt: double): void {
        const record = WeatherData.makeCacheRecord(payload, {
            location: location,
            coordinates: coords,
            city: cityName,
            countryCode: country,
            providerUrl: root.providerUrl,
            updatedAt: updatedAt
        });
        const serialized = JSON.stringify(record);
        root.cacheText = serialized;
        weatherCache.setText(serialized);
    }

    function describeError(error: var, metadata: var): string {
        const statusCode = Number(metadata?.statusCode);
        if (statusCode === 401 || statusCode === 403)
            return Tr.tr("The weather provider rejected the API key");
        if (statusCode === 429)
            return Tr.tr("The weather provider rate limit was reached");
        if (statusCode > 0)
            return Tr.tr("The weather request failed (HTTP %1)").arg(statusCode);
        return Tr.tr("The weather request failed: %1").arg(error);
    }

    function failWeather(message: string): void {
        root.errorMessage = message;
        root.status = root.hasData ? "stale" : "error";
        console.warn(lc, message);
    }

    function clearWeatherData(): void {
        root.cc = null;
        root.forecast = [];
        root.hourlyForecast = [];
        root.lastUpdated = 0;
        root.city = "";
        root.countryCode = "";
        root.loc = "";
        root.fromCache = false;
        root.errorMessage = "";
    }

    function resetWeather(newStatus: string, message: string): void {
        root.invalidateRequests();
        root.clearWeatherData();
        root.status = newStatus;
        root.errorMessage = message;
    }

    function invalidateRequests(): void {
        root.requestToken += 1;
        root.requestPending = false;
        root.geocodePending = false;
        root.searchToken += 1;
        root.searchPending = false;
    }

    function settingsChanged(): void {
        root.invalidateRequests();
        root.searchResults = [];
        root.searchMessage = "";
        // The settings store can emit several signals for one edit (location
        // and coordinates, for example). Coalesce them into one refresh.
        settingsReloadTimer.restart();
    }

    function getWeatherCondition(code: string): string {
        const conditions = {
            "0": Tr.tr("Clear"),
            "1": Tr.tr("Clear"),
            "2": Tr.tr("Partly cloudy"),
            "3": Tr.tr("Overcast"),
            "45": Tr.tr("Fog"),
            "48": Tr.tr("Fog"),
            "51": Tr.tr("Drizzle"),
            "53": Tr.tr("Drizzle"),
            "55": Tr.tr("Drizzle"),
            "56": Tr.tr("Freezing drizzle"),
            "57": Tr.tr("Freezing drizzle"),
            "61": Tr.tr("Light rain"),
            "63": Tr.tr("Rain"),
            "65": Tr.tr("Heavy rain"),
            "66": Tr.tr("Light rain"),
            "67": Tr.tr("Heavy rain"),
            "71": Tr.tr("Light snow"),
            "73": Tr.tr("Snow"),
            "75": Tr.tr("Heavy snow"),
            "77": Tr.tr("Snow"),
            "80": Tr.tr("Light rain"),
            "81": Tr.tr("Rain"),
            "82": Tr.tr("Heavy rain"),
            "85": Tr.tr("Light snow showers"),
            "86": Tr.tr("Heavy snow showers"),
            "95": Tr.tr("Thunderstorm"),
            "96": Tr.tr("Thunderstorm with hail"),
            "99": Tr.tr("Thunderstorm with hail")
        };
        return conditions[code] || Tr.trCtx("Unknown", "weather condition");
    }

    Component.onCompleted: root.reload()

    Connections {
        function onWeatherLocationChanged(): void {
            root.settingsChanged();
        }
        function onWeatherCoordinatesChanged(): void {
            root.settingsChanged();
        }
        function onWeatherProviderUrlChanged(): void {
            root.settingsChanged();
        }
        function onWeatherApiKeyChanged(): void {
            root.settingsChanged();
        }
        function onWeatherGeocodingUrlChanged(): void {
            root.settingsChanged();
        }
        function onWeatherLanguageChanged(): void {
            root.settingsChanged();
        }
        function onWeatherRefreshIntervalChanged(): void {
            root.invalidateRequests();
        }
        function onWeatherCacheTtlChanged(): void {
            root.reload();
        }

        target: GlobalConfig.services
    }

    Timer {
        interval: root.refreshSeconds * 1000
        running: root.configLoaded && root.savedLocation.length > 0
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: settingsReloadTimer

        interval: 50
        repeat: false
        onTriggered: root.reload()
    }

    // Only the relative "last updated" label needs this tick. Without a
    // location there is no label to age, so stay asleep.
    Timer {
        interval: 60000
        running: root.hasData
        repeat: true
        onTriggered: root.now = Date.now()
    }

    FileView {
        id: weatherConfig

        printErrors: false
        path: root.configPath
        watchChanges: true
        onFileChanged: weatherConfig.reload()
        onLoaded: {
            root.fileConfig = WeatherData.parseConfig(text());
            root.configLoaded = true;
            root.invalidateRequests();
            root.reload();
        }
        onLoadFailed: error => {
            root.fileConfig = ({});
            root.configLoaded = true;
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the weather config: ${error}`);
            root.reload();
        }
    }

    FileView {
        id: weatherCache

        printErrors: false
        path: `${Paths.cache}/weather.json`
        onLoaded: {
            root.cacheText = text();
            root.cacheLoaded = true;
            root.reload();
        }
        onLoadFailed: error => {
            root.cacheText = "";
            root.cacheLoaded = true;
            if (error !== FileViewError.FileNotFound)
                console.warn(lc, `Unable to load the weather cache: ${error}`);
            root.reload();
        }
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.services.weather"
        defaultLogLevel: LoggingCategory.Info
    }
}
