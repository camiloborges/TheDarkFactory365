// Program.cs
using Microsoft.Agents.Hosting.AspNetCore;
using Microsoft.Agents.Storage;
using Microsoft.SemanticKernel;
using SkWeatherAgent;
using SkWeatherAgent.Plugins;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHttpClient();

// Register Semantic Kernel
builder.Services.AddKernel();

// Register AI service — swap UseAzureOpenAI in appsettings to switch provider
if (builder.Configuration.GetSection("AIServices").GetValue<bool>("UseAzureOpenAI"))
{
    builder.Services.AddAzureOpenAIChatCompletion(
        deploymentName: builder.Configuration["AIServices:AzureOpenAI:DeploymentName"]!,
        endpoint: builder.Configuration["AIServices:AzureOpenAI:Endpoint"]!,
        apiKey: builder.Configuration["AIServices:AzureOpenAI:ApiKey"]!);
}
else
{
    builder.Services.AddOpenAIChatCompletion(
        modelId: builder.Configuration["AIServices:OpenAI:ModelId"]!,
        apiKey: builder.Configuration["AIServices:OpenAI:ApiKey"]!);
}

// Register SK plugins and agent
builder.Services.AddSingleton<WeatherPlugin>();
builder.Services.AddSingleton<ActivityAssessmentPlugin>();
builder.Services.AddSingleton<IStorage, MemoryStorage>();
builder.AddAgentApplicationOptions();
builder.AddAgent<WeatherAgent>();
builder.Services.AddAgentAspNetAuthentication(builder.Configuration);

var app = builder.Build();

app.UseAuthentication();
app.UseAuthorization();
app.MapAgentRootEndpoint();
app.MapAgentApplicationEndpoints(requireAuth: !app.Environment.IsDevelopment());

// ── POST /api/assess-activity ─────────────────────────────────────────────────
// Plain minimal API endpoint — bypasses Bot Framework activity routing.
// Called by Logic App (Option A) and Power Automate (Option B).
app.MapPost("/api/assess-activity", async (
    ActivityAssessmentRequest request,
    ActivityAssessmentPlugin plugin,
    IConfiguration config,
    HttpContext httpContext,
    CancellationToken cancellationToken) =>
{
    // API key validation — bypassed in Development environment
    if (!app.Environment.IsDevelopment())
    {
        var expectedKey = config["ActivityAdvisor:ApiKey"];
        if (string.IsNullOrEmpty(expectedKey))
            return Results.Problem("ActivityAdvisor:ApiKey is not configured.", statusCode: 500);

        if (!httpContext.Request.Headers.TryGetValue("X-Api-Key", out var providedKey) ||
            providedKey.ToString() != expectedKey)
        {
            return Results.Json(new { error = "unauthorized", message = "Missing or invalid X-Api-Key header." },
                statusCode: 401);
        }
    }

    // Input validation
    if (string.IsNullOrWhiteSpace(request.Activity) ||
        string.IsNullOrWhiteSpace(request.Location) ||
        string.IsNullOrWhiteSpace(request.Datetime))
    {
        return Results.Json(new { error = "invalid_request", message = "activity, location, and datetime are required." },
            statusCode: 400);
    }

    try
    {
        var result = await plugin.AssessActivityAsync(
            request.Activity, request.Location, request.Datetime, cancellationToken);

        return Results.Ok(new { risk = result.Risk, reason = result.Reason });
    }
    catch (InvalidOperationException ex) when (ex.Message.StartsWith("geocoding_failed"))
    {
        return Results.Json(new { error = "geocoding_failed", message = ex.Message.Replace("geocoding_failed: ", "") },
            statusCode: 502);
    }
    catch (InvalidOperationException ex) when (ex.Message.StartsWith("assessment_failed"))
    {
        return Results.Json(new { error = "assessment_failed", message = ex.Message.Replace("assessment_failed: ", "") },
            statusCode: 502);
    }
    catch (HttpRequestException ex)
    {
        return Results.Json(new { error = "forecast_failed", message = $"Weather API unreachable: {ex.Message}" },
            statusCode: 502);
    }
});

app.Run();

// ── Request model ─────────────────────────────────────────────────────────────
public record ActivityAssessmentRequest(string Activity, string Location, string Datetime);
