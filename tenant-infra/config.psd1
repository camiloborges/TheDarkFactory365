# DarkFactory365 Provisioning Configuration
# All static values for the aiwhisperer.onmicrosoft.com tenant.
# Runtime values (home location, guest emails) are supplied as script parameters.
@{
    Tenant = @{
        Domain   = 'aiwhisperer.onmicrosoft.com'
        AdminUrl = 'https://aiwhisperer-admin.sharepoint.com'
    }

    Site = @{
        Title  = 'DarkFactory'
        Alias  = 'DarkFactory'
        Url    = 'https://aiwhisperer.sharepoint.com/sites/DarkFactory'
        Groups = @{
            Owners   = 'DarkFactory Owners'
            Members  = 'DarkFactory Members'
            Visitors = 'DarkFactory Visitors'
        }
    }

    AppCatalog = @{
        Url        = 'https://aiwhisperer.sharepoint.com/sites/appcatalog'
        Owner      = 'camilo.borges@aiwhisperer.onmicrosoft.com'
        TimeZoneId = 17  # (UTC+12:00) Auckland, Wellington
    }

    ConfigList = @{
        Name       = 'DarkFactory-Settings'
        Categories = @('Weather', 'Alerts', 'General')
    }

    Teams = @{
        Name    = 'DarkFactory'
        Channel = 'General'
    }

    # CSP sources to add to the SharePoint tenant allowlist (connect-src directive).
    # Add new API domains here as new specs introduce external calls.
    CSP = @{
        Sources = @(
            'https://api.open-meteo.com'
        )
    }

    # Fixed seed entries written to DarkFactory-Settings on first run.
    # Location-specific entries (Latitude, Longitude, Timezone, LocationName, City)
    # are supplied at runtime via script parameters and merged at run time.
    SeedData = @{
        Fixed = @(
            @{
                Key         = 'Weather.ApiBaseUrl'
                Value       = 'https://api.open-meteo.com/v1/forecast'
                Category    = 'Weather'
                Description = 'Open-Meteo API base URL — override for staging/testing'
            }
            @{
                Key         = 'Weather.TemperatureUnit'
                Value       = 'celsius'
                Category    = 'Weather'
                Description = 'Temperature unit: celsius or fahrenheit'
            }
            @{
                Key         = 'Weather.RefreshIntervalMinutes'
                Value       = '5'
                Category    = 'Weather'
                Description = 'Web part auto-refresh interval in minutes'
            }
        )
    }
}
