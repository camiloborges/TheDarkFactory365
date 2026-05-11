import { Version } from '@microsoft/sp-core-library';
import { BaseClientSideWebPart, IPropertyPaneConfiguration, PropertyPaneTextField } from '@microsoft/sp-webpart-base';
import { SPHttpClient } from '@microsoft/sp-http';
import * as React from 'react';
import * as ReactDom from 'react-dom';
import { ConfigService, IHttpClient } from './services/ConfigService';
import { DarkFactoryWeather, IDarkFactoryWeatherProps } from './components/DarkFactoryWeather';

export interface IDarkFactoryWeatherWebPartProps {
  configListName: string;
}

export default class DarkFactoryWeatherWebPart extends BaseClientSideWebPart<IDarkFactoryWeatherWebPartProps> {
  private configService!: ConfigService;
  private isTeams: boolean = false;

  public async onInit(): Promise<void> {
    await super.onInit();

    this.isTeams = !!(this.context.sdks && this.context.sdks.microsoftTeams);

    const spClient = this.context.spHttpClient;
    const httpAdapter: IHttpClient = {
      get: (url: string) => spClient.get(url, SPHttpClient.configurations.v1)
    };

    this.configService = new ConfigService(
      httpAdapter,
      this.context.pageContext.web.absoluteUrl,
      this.properties.configListName || 'DarkFactory-Settings'
    );
  }

  public render(): void {
    const element: React.ReactElement<IDarkFactoryWeatherProps> = React.createElement(
      DarkFactoryWeather,
      {
        configService: this.configService,
        siteUrl: this.context.pageContext.web.absoluteUrl,
        isTeams: this.isTeams
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected onDispose(): void {
    ReactDom.unmountComponentAtNode(this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: { description: 'Dark Factory Weather Settings' },
          groups: [
            {
              groupName: 'Configuration',
              groupFields: [
                PropertyPaneTextField('configListName', {
                  label: 'Config list name',
                  value: this.properties.configListName || 'DarkFactory-Settings'
                })
              ]
            }
          ]
        }
      ]
    };
  }
}
