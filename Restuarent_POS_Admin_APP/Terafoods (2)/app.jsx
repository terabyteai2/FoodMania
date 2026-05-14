// App shell — phone frame, bottom nav, active screen.
// Orders is the default landing screen.

const DEFAULT_TWEAKS = /*EDITMODE-BEGIN*/{
  "dashboardLayout": "A",
  "accent": "#F2C744"
}/*EDITMODE-END*/;

function App() {
  const [tweaks, setTweak] = useTweaks(DEFAULT_TWEAKS);
  const [tab, setTab] = React.useState('orders');

  // apply accent override to tokens (live)
  React.useEffect(() => {
    if (tweaks.accent && tweaks.accent !== tokens.brand) {
      tokens.brand = tweaks.accent;
      tokens.brandDim = tweaks.accent + '24';
      tokens.brandRim = tweaks.accent + '52';
    }
  }, [tweaks.accent]);

  const screen = (() => {
    switch (tab) {
      case 'orders': return <OrdersScreen />;
      case 'dashboard': return <DashboardScreen layout={tweaks.dashboardLayout} />;
      case 'menu': return <MenuScreen />;
      case 'settings': return <SettingsScreen />;
      default: return <OrdersScreen />;
    }
  })();

  return (
    <div style={{
      minHeight: '100vh', display: 'grid', placeItems: 'center',
      padding: '40px 20px',
      background: `radial-gradient(circle at 50% 0%, #1a1714 0%, #0a0908 60%)`,
    }}>
      <Phone>
        {/* re-key on tab so internal state resets cleanly */}
        <div key={tab} style={{ height: '100%' }}>
          {screen}
        </div>
        <BottomNav active={tab} onChange={setTab} />
      </Phone>

      <TweaksPanel title="Tweaks">
        <TweakSection title="Dashboard layout">
          <TweakRadio
            label="Variant"
            value={tweaks.dashboardLayout}
            onChange={v => setTweak('dashboardLayout', v)}
            options={[
              { label: 'Hero + grid', value: 'A' },
              { label: 'Giant number', value: 'B' },
            ]} />
          <div style={{ fontSize: 11, color: '#9a9388', marginTop: 6, lineHeight: 1.4 }}>
            Tap the Insights tab to see this take effect.
          </div>
        </TweakSection>

        <TweakSection title="Accent">
          <TweakColor
            label="Brand color"
            value={tweaks.accent}
            onChange={v => setTweak('accent', v)}
            options={['#F2C744', '#E8C547', '#FFD928', '#E89C3F', '#7BB47C', '#74A6D8']} />
          <div style={{ fontSize: 11, color: '#9a9388', marginTop: 6, lineHeight: 1.4 }}>
            Refresh the page after picking to fully repaint.
          </div>
        </TweakSection>
      </TweaksPanel>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
