// WeatherAgent.cs
using Microsoft.Agents.Builder;
using Microsoft.Agents.Builder.App;
using Microsoft.Agents.Builder.State;
using Microsoft.Agents.Core.Models;
using Microsoft.SemanticKernel;
using Microsoft.SemanticKernel.ChatCompletion;
using Microsoft.SemanticKernel.Connectors.OpenAI;
using SkWeatherAgent.Plugins;

namespace SkWeatherAgent;

public class WeatherAgent : AgentApplication
{
    private readonly Kernel _kernel;

    public WeatherAgent(AgentApplicationOptions options, Kernel kernel, WeatherPlugin weatherPlugin)
        : base(options)
    {
        _kernel = kernel;
        _kernel.Plugins.AddFromObject(weatherPlugin, "Weather");

        OnConversationUpdate(ConversationUpdateEvents.MembersAdded, WelcomeAsync);
        OnActivity(ActivityTypes.Message, OnMessageAsync, rank: RouteRank.Last);

        OnTurnError(async (context, state, ex, ct) =>
        {
            Console.Error.WriteLine($"[Turn error] {ex.Message}");
            await context.SendActivityAsync("Something went wrong. Please try again.", cancellationToken: ct);
        });
    }

    private async Task WelcomeAsync(ITurnContext context, ITurnState state, CancellationToken ct)
    {
        foreach (ChannelAccount member in context.Activity.MembersAdded)
        {
            if (member.Id != context.Activity.Recipient.Id)
            {
                await context.SendActivityAsync(
                    MessageFactory.Text("Hello! Ask me about the weather anywhere — e.g. \"What's the weather in Wellington?\""),
                    ct);
            }
        }
    }

    private async Task OnMessageAsync(ITurnContext context, ITurnState state, CancellationToken ct)
    {
        // Maintain chat history across turns (stored in conversation-scoped turn state)
        var chatHistory = state.Conversation.GetValue<ChatHistory>(
            "chatHistory",
            () => new ChatHistory("You are a helpful weather assistant. Use the Weather plugin to answer questions about current conditions and forecasts.")
        );

        chatHistory.AddUserMessage(context.Activity.Text);

        var settings = new OpenAIPromptExecutionSettings
        {
            ToolCallBehavior = ToolCallBehavior.AutoInvokeKernelFunctions
        };

        var chatCompletion = _kernel.GetRequiredService<IChatCompletionService>();
        var response = await chatCompletion.GetChatMessageContentAsync(
            chatHistory,
            settings,
            _kernel,
            ct);

        chatHistory.AddAssistantMessage(response.Content!);
        state.Conversation.SetValue("chatHistory", chatHistory);

        // Stream informative update then send the final response
        await context.StreamingResponse.QueueInformativeUpdateAsync("Checking the weather...", ct);
        context.StreamingResponse.QueueTextChunk(response.Content!);
        await context.StreamingResponse.EndStreamAsync(ct);
    }
}
